#!/usr/bin/env python3
"""Bounded Dev-only DynamoDB COUNT inventory; never retrieve item contents."""

import argparse
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


ACCOUNT = "107827791950"
REGION = "us-east-1"
PREFIX = "trustcheckradar-dev"
TABLES = (f"{PREFIX}-analysis-abuse-control", f"{PREFIX}-deletion-ledger")
FAMILIES = ("REQUEST", "RATE", "SCAN_RATE", "CONSUMPTION")
COMPONENTS = ("SESSION_REVOCATION", "DEVICE_BINDINGS", "DEVICE_RECOVERY",
              "ANALYSIS_ABUSE", "HISTORY", "CAMPAIGN")
STATUSES = ("PROCESSING", "RETRYABLE", "RESULT_READY", "COMPLETED", "COMPLETED_ERASED")

# Use the SDK bundled with the installed Python AWS CLI. The CLI's parameter
# handlers can read file:///dev/stdin twice; SDK calls avoid that and CLI history.
SDK_WORKER = r'''
import json, logging, sys
logging.disable(logging.CRITICAL)
try:
    from awscli.botocore.session import Session
    from awscli.botocore.config import Config
    request = json.load(sys.stdin)
    operations = {("sts", "get-caller-identity"): "GetCallerIdentity",
                  ("dynamodb", "describe-table"): "DescribeTable",
                  ("dynamodb", "scan"): "Scan"}
    service, operation = request["service"], request["operation"]
    payload = request["payload"]
    if service == "dynamodb" and payload.get("TableName") not in (
        "trustcheckradar-dev-analysis-abuse-control", "trustcheckradar-dev-deletion-ledger"
    ):
        raise ValueError("Scope")
    if operation == "scan" and (payload.get("Select") != "COUNT" or payload.get("Limit") != 25
            or "ProjectionExpression" in payload or "IndexName" in payload):
        raise ValueError("Scope")
    session = Session(profile=request["profile"])
    client = session.create_client(service, region_name="us-east-1", config=Config(
        retries={"max_attempts": 1}, connect_timeout=5, read_timeout=20))
    response = client._make_api_call(operations[(service, operation)], payload)
    if service == "sts":
        response = {"Account": response.get("Account")}
    elif operation == "describe-table":
        response = {"Table": {"TableArn": response.get("Table", {}).get("TableArn")}}
    else:
        response.pop("ResponseMetadata", None)
        if set(response) - {"Count", "ScannedCount", "ConsumedCapacity", "LastEvaluatedKey"}:
            raise ValueError("Unexpected response")
    print(json.dumps(response))
except Exception as error:
    code = "aws_read_failed"
    if type(error).__name__ in {"UnauthorizedSSOTokenError", "SSOTokenLoadError", "TokenRetrievalError"}:
        code = "aws_session_expired"
    elif getattr(error, "response", {}).get("Error", {}).get("Code") in {"AccessDenied", "AccessDeniedException"}:
        code = "aws_read_denied"
    elif type(error).__name__ in {"EndpointConnectionError", "ConnectTimeoutError", "ReadTimeoutError"}:
        code = "aws_connectivity"
    print(json.dumps({"auditError": code}))
'''


class AuditError(RuntimeError):
    def __init__(self, message, *, code="audit_guard"):
        super().__init__(message)
        self.code = code


def sdk_python():
    executable = shutil.which("aws")
    if not executable:
        raise AuditError("AWS CLI is unavailable.")
    with Path(executable).resolve().open("rb") as script:
        header = script.readline(512).decode("utf-8", errors="strict").strip()
    interpreter = header.removeprefix("#!")
    if not header.startswith("#!/") or "python" not in Path(interpreter).name or not Path(interpreter).is_file():
        raise AuditError("A Python-based AWS CLI runtime is required for private SDK input.")
    return interpreter


def aws_reader(profile):
    def read(service, operation, payload):
        if (service, operation) not in {
            ("sts", "get-caller-identity"), ("dynamodb", "describe-table"),
            ("dynamodb", "scan"),
        }:
            raise AuditError("Operation is outside the read-only inventory scope.")
        if service == "dynamodb" and payload.get("TableName") not in TABLES:
            raise AuditError("Table is outside the approved Dev scope.")
        if operation == "scan" and (
            payload.get("Select") != "COUNT" or "ProjectionExpression" in payload
            or "IndexName" in payload or payload.get("Limit") != 25
            or payload.get("ConsistentRead") is not False
        ):
            raise AuditError("Scan must be bounded, table-only and count-only.")
        # Pass pagination keys through stdin, never command arguments or files.
        command = [sdk_python(), "-c", SDK_WORKER]
        result = subprocess.run(
            command, input=json.dumps({"profile": profile, "service": service,
                                      "operation": operation, "payload": payload}),
            capture_output=True, text=True,
            timeout=30, env={**os.environ, "AWS_MAX_ATTEMPTS": "1", "AWS_PAGER": ""},
        )
        if result.returncode:
            code = "aws_read_failed"
            if "Token has expired" in result.stderr or "Error loading SSO Token" in result.stderr:
                code = "aws_session_expired"
            elif "AccessDenied" in result.stderr or "Unauthorized" in result.stderr:
                code = "aws_read_denied"
            elif "Could not connect to the endpoint" in result.stderr:
                code = "aws_connectivity"
            raise AuditError("AWS read failed; no raw CLI output is emitted.", code=code)
        response = json.loads(result.stdout)
        if isinstance(response, dict) and "auditError" in response:
            raise AuditError("AWS SDK read failed; details suppressed.", code=response["auditError"])
        return response
    return read


class Counter:
    def __init__(self, read, *, max_calls=80, max_units=64, max_pages=10,
                 clock=time.monotonic, sleep=time.sleep):
        self.read = read
        self.max_calls = max_calls
        self.max_units = max_units
        self.max_pages = max_pages
        self.clock = clock
        self.sleep = sleep
        self.started = clock()
        self.calls = 0
        self.units = 0.0
        self.stop_reason = None

    def count(self, table, expression, names, values):
        total = scanned = pages = 0
        key = None
        while True:
            if self.calls >= self.max_calls:
                self.stop_reason = "request_budget"
            elif self.units >= self.max_units:
                self.stop_reason = "consumed_capacity_budget"
            elif self.clock() - self.started >= 300:
                self.stop_reason = "elapsed_time_budget"
            if self.stop_reason:
                return {"count": total, "complete": False, "pages": pages,
                        "evaluated": scanned, "stoppedBecause": self.stop_reason}
            if self.calls:
                self.sleep(0.25)
            payload = {
                "TableName": table, "Select": "COUNT", "Limit": 25,
                "ConsistentRead": False, "ReturnConsumedCapacity": "TOTAL",
                "FilterExpression": expression,
                "ExpressionAttributeNames": names,
                "ExpressionAttributeValues": values,
            }
            if key:
                payload["ExclusiveStartKey"] = key
            response = self.read("dynamodb", "scan", payload)
            self.calls += 1
            if not isinstance(response, dict) or set(response) - {
                "Count", "ScannedCount", "ConsumedCapacity", "LastEvaluatedKey",
            }:
                raise AuditError("Unexpected count-only response shape; output suppressed.")
            count, evaluated = response.get("Count"), response.get("ScannedCount")
            units = response.get("ConsumedCapacity", {}).get("CapacityUnits")
            if (type(count) is not int or type(evaluated) is not int
                    or not 0 <= count <= evaluated <= 25
                    or type(units) not in (int, float) or not math.isfinite(units) or units < 0):
                raise AuditError("Invalid count/capacity metadata; output suppressed.")
            total += count
            scanned += evaluated
            self.units += units
            pages += 1
            next_key = response.get("LastEvaluatedKey")
            if not next_key:
                return {"count": total, "complete": True, "pages": pages, "evaluated": scanned}
            if (not isinstance(next_key, dict) or set(next_key) != {"PK", "SK"}
                    or any(not isinstance(v, dict) or set(v) != {"S"}
                           or not isinstance(v["S"], str) for v in next_key.values())):
                raise AuditError("Invalid private pagination metadata; output suppressed.")
            if next_key == key:
                raise AuditError("Repeated pagination key; output suppressed.")
            if pages >= self.max_pages:
                self.stop_reason = "per_aggregation_page_budget"
                return {"count": total, "complete": False, "pages": pages,
                        "evaluated": scanned, "stoppedBecause": self.stop_reason}
            key = next_key


def expiry_filters(now):
    result = [
        ("missing", "attribute_not_exists(#expiry)", {}),
        ("non_numeric", "attribute_exists(#expiry) AND NOT attribute_type(#expiry, :number)",
         {":number": {"S": "N"}}),
        ("expired", "#expiry <= :upper", {":upper": {"N": str(now)}}),
    ]
    lower = now
    for label, seconds in (("up_to_15_minutes", 900), ("15_minutes_to_24_hours", 86400),
                           ("24_hours_to_7_days", 7 * 86400),
                           ("7_to_120_days", 120 * 86400)):
        upper = now + seconds
        result.append((label, "#expiry > :lower AND #expiry <= :upper",
                       {":lower": {"N": str(lower)}, ":upper": {"N": str(upper)}}))
        lower = upper
    result.append(("over_120_days", "#expiry > :lower", {":lower": {"N": str(lower)}}))
    return result


def collect(read, *, now=None, counter=None):
    identity = read("sts", "get-caller-identity", {})
    if identity.get("Account") != ACCOUNT:
        raise AuditError("Unexpected AWS account; no table reads performed.")
    for table in TABLES:
        description = read("dynamodb", "describe-table", {"TableName": table})
        if description.get("Table", {}).get("TableArn") != f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{table}":
            raise AuditError("Unexpected Dev table identity; no scans performed.")
    now = int(time.time()) if now is None else now
    counter = counter or Counter(read)
    report = {
        "schemaVersion": 1, "accountId": ACCOUNT, "environment": "dev", "region": REGION,
        "scope": "analysis-and-known-component-receipts-count-only",
        "asOfEpoch": now, "complete": True, "deletionReadinessVerified": False,
        "analysis": {}, "componentReceipts": {},
        "limits": {"maxScanCalls": counter.max_calls, "maxPagesPerAggregation": counter.max_pages,
                   "stopAfterConsumedCapacityUnits": counter.max_units, "maxSeconds": 300,
                   "evaluatedItemsPerPage": 25},
        "limitations": [
            "No item contents returned. Private pagination keys are kept only in memory/stdin, never reported.",
            "Each count is a separate eventually consistent scan, not a shared point-in-time snapshot.",
            "Expiry buckets measure remaining lifetime, not original retention or History provenance.",
            "No unknown field discovery, identifier/hash verification, or arbitrary status values are returned.",
            "Known receipt-key counts do not validate operation binding, signatures, or exact receipt schemas.",
            "Empty families skip detailed scans; concurrent new writes may appear after that observation.",
            "Count-only filters still consume read capacity; stop thresholds may be exceeded by one bounded page.",
            "No backups, other tables, user records, logs, exports, or deployment changes are included.",
        ],
    }

    def inventory_group(table, base, names, values, expiry, *, statuses=False):
        group = {"total": counter.count(table, base, names, values)}
        if not group["total"]["complete"] or not group["total"]["count"]:
            group["detailsSkipped"] = True
            return group
        group["expiryBuckets"] = {}
        for label, condition, extra in expiry_filters(now):
            if counter.stop_reason:
                break
            group["expiryBuckets"][label] = counter.count(
                table, f"({base}) AND ({condition})", {**names, "#expiry": expiry}, {**values, **extra},
            )
        if statuses and not counter.stop_reason:
            group["knownStatuses"] = {}
            for status in STATUSES:
                if counter.stop_reason:
                    break
                group["knownStatuses"][status] = counter.count(
                    table, f"({base}) AND #status = :status", {**names, "#status": "status"},
                    {**values, ":status": {"S": status}},
                )
        return group

    for family in FAMILIES:
        if counter.stop_reason:
            break
        report["analysis"][family] = inventory_group(
            TABLES[0], "begins_with(#pk, :family)", {"#pk": "PK"},
            {":family": {"S": f"ANALYSIS#{family}#"}}, "expiresAt", statuses=family == "REQUEST",
        )
    if not counter.stop_reason:
        names = {"#pk": "PK", "#sk": "SK"}
        values = {":account": {"S": "ACCOUNT#"}}
        for index, component in enumerate(COMPONENTS):
            values[f":component{index}"] = {"S": f"ACCOUNT_DELETION#{component}"}
        base = "begins_with(#pk, :account) AND #sk IN (" + ", ".join(
            f":component{index}" for index in range(len(COMPONENTS))
        ) + ")"
        report["componentReceipts"] = inventory_group(TABLES[1], base, names, values, "retainUntilEpoch")
    report["complete"] = counter.stop_reason is None
    report["scanCalls"] = counter.calls
    report["consumedCapacityUnits"] = counter.units
    if counter.stop_reason:
        report["stoppedBecause"] = counter.stop_reason
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default="trustcheckradar")
    args = parser.parse_args()
    try:
        report = collect(aws_reader(args.profile))
    except (AuditError, OSError, subprocess.TimeoutExpired, ValueError, KeyError, TypeError) as error:
        # Exceptions/CLI stderr can include request keys; never emit their text.
        code = getattr(error, "code", "audit_guard")
        if code not in {"aws_read_failed", "aws_session_expired", "aws_read_denied", "aws_connectivity"}:
            code = "audit_guard"
        print(f"Count inventory failed ({code}); raw AWS output and exception details suppressed.", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["complete"] else 2


if __name__ == "__main__":
    sys.exit(main())
