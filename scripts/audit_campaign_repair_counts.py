#!/usr/bin/env python3
"""Bounded aggregate-only campaign repair schema audit; never fetch item values."""
import argparse
import datetime
import json
import time


class AuditError(Exception):
    pass


def collect(client, *, account, region, table, max_pages=10, page_size=1000,
            seconds=60, monotonic=time.monotonic):
    if not (1 <= max_pages <= 100 and 1 <= page_size <= 1000 and 1 <= seconds <= 300):
        raise AuditError("invalid_bounds")
    expected = f"arn:aws:dynamodb:{region}:{account}:table/{table}"
    if client.describe_table(TableName=table)["Table"]["TableArn"] != expected:
        raise AuditError("table_identity_mismatch")
    names = {"#pk": "PK", "#sk": "SK"}
    candidate = {":candidate": {"S": "CANDIDATE#"}}
    missing = "(attribute_not_exists(#mv) OR #mv <> :one OR attribute_not_exists(#lex) OR attribute_not_exists(#signals) OR attribute_not_exists(#indicators))"
    deadline = monotonic() + seconds
    results = {}
    for family, predicate, value in (
        ("contributions", "begins_with(#sk,:kind)", "CONTRIB#"),
        ("repairCheckpoints", "#sk=:kind", "DELETION_RECOMPUTE"),
    ):
        for schema_check in (False, True):
            expr = f"begins_with(#pk,:candidate) AND {predicate}"
            attrs = dict(names)
            values = {**candidate, ":kind": {"S": value}}
            if schema_check:
                expr += " AND " + missing
                attrs.update({"#mv": "metadataSchemaVersion", "#lex": "lexicalFingerprint",
                              "#signals": "signalIds", "#indicators": "indicatorIds"})
                values[":one"] = {"N": "1"}
            result = {"count": 0, "scannedCount": 0, "pages": 0, "traversalComplete": False}
            cursor = None
            for _ in range(max_pages):
                if monotonic() >= deadline:
                    result["stopReason"] = "time_budget"
                    break
                request = dict(TableName=table, Select="COUNT", ConsistentRead=True,
                               Limit=page_size, FilterExpression=expr,
                               ExpressionAttributeNames=attrs, ExpressionAttributeValues=values)
                if cursor:
                    request["ExclusiveStartKey"] = cursor
                page = client.scan(**request)
                if "Items" in page:
                    raise AuditError("unexpected_item_values")
                for key in ("Count", "ScannedCount"):
                    if type(page.get(key)) is not int or page[key] < 0:
                        raise AuditError("invalid_count_response")
                result["count"] += page["Count"]
                result["scannedCount"] += page["ScannedCount"]
                result["pages"] += 1
                cursor = page.get("LastEvaluatedKey")
                if not cursor:
                    result["traversalComplete"] = True
                    result["stopReason"] = "enumerated"
                    break
            if "stopReason" not in result:
                result["stopReason"] = "page_budget"
            results[family + ("MissingReconstructionSchema" if schema_check else "")] = result
    return {
        "schemaVersion": 1, "observedAtUtc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "accountId": account, "region": region, "table": table,
        "mode": "read-only Select=COUNT", "bounds": {"maxPagesPerCount": max_pages, "pageSize": page_size, "seconds": seconds},
        "counts": results, "allTraversalsComplete": all(v["traversalComplete"] for v in results.values()),
        "inventoryApproved": False, "erasureVerified": False,
        "limitations": [
            "Separate strongly consistent scans are not one frozen snapshot.",
            "Schema presence/version does not establish valid reconstruction fields or complete historical coverage.",
            "Counts exclude other key families and all external, restored, expired or retired copies.",
            "No item values or pagination identifiers are retained; no markers or application records are changed.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default="trustcheckradar")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    import boto3
    from botocore.config import Config
    from pathlib import Path
    account, region = "107827791950", "us-east-1"
    config = Config(connect_timeout=5, read_timeout=15, retries={"total_max_attempts": 1})
    try:
        session = boto3.Session(profile_name=args.profile, region_name=region)
        if session.client("sts", config=config).get_caller_identity()["Account"] != account:
            raise AuditError("account_mismatch")
        report = collect(session.client("dynamodb", config=config), account=account, region=region,
                         table="trustcheckradar-dev-campaign-pipeline")
        Path(args.output).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(json.dumps({"completed": report["allTraversalsComplete"], "output": args.output}))
        return 0 if report["allTraversalsComplete"] else 2
    except Exception as exc:
        print(json.dumps({"completed": False, "reason": str(exc) if isinstance(exc, AuditError) else "audit_operation_failed"}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
