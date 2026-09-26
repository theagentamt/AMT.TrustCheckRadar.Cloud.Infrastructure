#!/usr/bin/env python3
"""Bounded Dev Cognito/profile mapping observation; reports counts, never identities."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import time

ACCOUNT = "107827791950"
REGION = "us-east-1"
POOL = "us-east-1_wzN0wUSdQ"
TABLE = "trustcheckradar-dev-users"
UUID = re.compile(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}")


def collect(cognito, ddb, *, max_pages=10, clock=time.monotonic):
    if type(max_pages) is not int or not 1 <= max_pages <= 10:
        raise ValueError("INVALID_BOUND")
    deadline = clock() + 60
    result = {
        "schemaVersion": 1, "observedAtUtc": datetime.now(timezone.utc).isoformat(),
        "accountId": ACCOUNT, "region": REGION, "environment": "dev",
        "poolId": POOL, "tableName": TABLE,
        "cognitoComplete": False, "profilesComplete": False,
        "usersExamined": 0, "profilesExamined": 0,
        "invalidIdentity": 0, "duplicateIdentity": 0, "usernameMismatch": 0,
        "invalidProfile": 0, "duplicateProfile": 0,
        "identityWithoutProfile": None, "profileWithoutIdentity": None,
        "currentMappingConsistent": False, "usernameSubConsistent": False,
        "missingProfileByUserStatus": {}, "inventoryApproved": False,
        "limitations": [
            "Separate bounded observations, not a frozen cross-service snapshot.",
            "Current identity/profile mapping only; no historical inventory or deletion approval.",
            "No identities, attributes, tokens or pagination values are retained in the report."
        ],
    }
    def call(fn, **kwargs):
        if clock() >= deadline:
            raise TimeoutError("TIME_BOUND")
        return fn(**kwargs)
    identities, profiles = set(), set()
    identity_status = {}
    try:
        pool = call(cognito.describe_user_pool, UserPoolId=POOL)["UserPool"]
        table = call(ddb.describe_table, TableName=TABLE)["Table"]
        if pool["Arn"] != f"arn:aws:cognito-idp:{REGION}:{ACCOUNT}:userpool/{POOL}" or table["TableArn"] != f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{TABLE}":
            raise ValueError("WRONG_RESOURCE")
        cursor = None
        for _ in range(max_pages):
            page = call(cognito.list_users, UserPoolId=POOL, Limit=60,
                        AttributesToGet=["sub"], **({"PaginationToken": cursor} if cursor else {}))
            for user in page["Users"]:
                result["usersExamined"] += 1
                values = [x.get("Value") for x in user.get("Attributes", []) if x.get("Name") == "sub"]
                if len(values) != 1 or not isinstance(values[0], str) or not UUID.fullmatch(values[0]):
                    result["invalidIdentity"] += 1
                    continue
                sub = values[0]
                if user.get("Username") != sub:
                    result["usernameMismatch"] += 1
                if sub in identities:
                    result["duplicateIdentity"] += 1
                identities.add(sub)
                status = user.get("UserStatus")
                identity_status[sub] = status if status in {"UNCONFIRMED", "CONFIRMED", "ARCHIVED", "COMPROMISED", "UNKNOWN", "RESET_REQUIRED", "FORCE_CHANGE_PASSWORD", "EXTERNAL_PROVIDER"} else "UNKNOWN"
            cursor = page.get("PaginationToken")
            if not cursor:
                result["cognitoComplete"] = True
                break
        cursor = None
        for _ in range(max_pages):
            page = call(ddb.scan, TableName=TABLE, ConsistentRead=True, Limit=100,
                        ProjectionExpression="#pk,#sk,#sub",
                        ExpressionAttributeNames={"#pk": "PK", "#sk": "SK", "#sub": "sub"},
                        **({"ExclusiveStartKey": cursor} if cursor else {}))
            for row in page["Items"]:
                if row.get("SK") != {"S": "PROFILE"}:
                    continue
                result["profilesExamined"] += 1
                sub = row.get("sub", {}).get("S")
                if not isinstance(sub, str) or not UUID.fullmatch(sub) or row.get("PK") != {"S": "USER#" + sub}:
                    result["invalidProfile"] += 1
                    continue
                if sub in profiles:
                    result["duplicateProfile"] += 1
                profiles.add(sub)
            cursor = page.get("LastEvaluatedKey")
            if not cursor:
                result["profilesComplete"] = True
                break
        result["usernameSubConsistent"] = result["cognitoComplete"] and all(result[key] == 0 for key in ("invalidIdentity", "duplicateIdentity", "usernameMismatch"))
        if result["cognitoComplete"] and result["profilesComplete"]:
            result["identityWithoutProfile"] = len(identities - profiles)
            result["profileWithoutIdentity"] = len(profiles - identities)
            for sub in identities - profiles:
                status = identity_status[sub]
                counts = result["missingProfileByUserStatus"]
                counts[status] = counts.get(status, 0) + 1
            result["currentMappingConsistent"] = all(result[key] == 0 for key in (
                "invalidIdentity", "duplicateIdentity", "usernameMismatch", "invalidProfile",
                "duplicateProfile", "identityWithoutProfile", "profileWithoutIdentity"))
    except Exception:
        result["reason"] = "OBSERVATION_UNAVAILABLE"
    return result


def main():
    import boto3
    from botocore.config import Config
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--profile", default="trustcheckradar")
    args = parser.parse_args()
    try:
        session = boto3.Session(profile_name=args.profile, region_name=REGION)
        config = Config(connect_timeout=5, read_timeout=10, retries={"total_max_attempts": 1})
        if session.client("sts", config=config).get_caller_identity()["Account"] != ACCOUNT:
            raise ValueError("WRONG_ACCOUNT")
        result = collect(session.client("cognito-idp", config=config), session.client("dynamodb", config=config))
        Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps({key: result[key] for key in ("cognitoComplete", "profilesComplete", "currentMappingConsistent", "inventoryApproved")}))
        return 0 if result["cognitoComplete"] and result["profilesComplete"] else 2
    except Exception:
        print('{"reason":"AUDIT_UNAVAILABLE"}')
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
