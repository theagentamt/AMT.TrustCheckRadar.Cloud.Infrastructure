"""Initialize only the empty Dev export cursor secret; never rotate existing keys."""
import argparse
import base64
from contextlib import closing
import hmac
import json
import re
import secrets
import uuid

ACCOUNT = "107827791950"
REGION = "us-east-1"
NAME = "trustcheckradar/dev/account-export-cursor"


class InitializationBlocked(RuntimeError):
    pass


def initialize(sts, client):
    if sts.get_caller_identity()["Account"] != ACCOUNT:
        raise InitializationBlocked("Wrong AWS account; no secret access attempted.")
    metadata = client.describe_secret(SecretId=NAME)
    arn = metadata.get("ARN", "")
    if (not re.fullmatch(rf"arn:aws:secretsmanager:{REGION}:{ACCOUNT}:secret:{NAME}-[A-Za-z0-9]{{6}}", arn)
            or metadata.get("DeletedDate") or metadata.get("RotationEnabled")):
        raise InitializationBlocked("Secret identity or lifecycle does not match the initial setup.")
    # Include deprecated versions: an earlier interrupted setup is not an empty secret.
    versions = client.list_secret_version_ids(SecretId=arn, IncludeDeprecated=True)
    if metadata.get("VersionIdsToStages") or versions.get("Versions") or versions.get("NextToken"):
        raise InitializationBlocked("Secret already has versions; inspect existing setup instead of rotating.")
    version = str(uuid.uuid4())
    label = "INIT_" + version.replace("-", "")
    payload = json.dumps({"activeKeyId": "k1", "keys": {"k1": base64.b64encode(secrets.token_bytes(32)).decode("ascii")}}, separators=(",", ":"))
    # Explicit staging never moves another writer's AWSCURRENT. AWS may assign
    # AWSCURRENT automatically if this wins the race to create the first version.
    result = client.put_secret_value(SecretId=arn, ClientRequestToken=version, SecretString=payload, VersionStages=[label])
    if result.get("VersionId") != version:
        raise InitializationBlocked("Unexpected version result; inspect setup metadata before retrying.")
    current = client.describe_secret(SecretId=arn).get("VersionIdsToStages", {})
    if any(v != version and "AWSCURRENT" in stages for v, stages in current.items()):
        raise InitializationBlocked("Another initialization became current; no existing current key was replaced.")
    if "AWSCURRENT" not in current.get(version, []):
        # Without RemoveFromVersionId AWS rejects moving an existing current label.
        client.update_secret_version_stage(SecretId=arn, VersionStage="AWSCURRENT", MoveToVersionId=version)
    observed = client.get_secret_value(SecretId=arn, VersionId=version, VersionStage="AWSCURRENT")
    if observed.get("VersionId") != version or not hmac.compare_digest(observed.get("SecretString", ""), payload):
        raise InitializationBlocked("Current version verification failed; inspect setup before retrying.")
    client.update_secret_version_stage(SecretId=arn, VersionStage=label, RemoveFromVersionId=version)
    return {"secretName": NAME, "versionId": version, "activeKeyId": "k1", "keyCount": 1, "currentVerified": True, "runtimeActivated": False}


def main():
    import boto3
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default="trustcheckradar")
    args = parser.parse_args()
    session = boto3.Session(profile_name=args.profile, region_name=REGION)
    try:
        with closing(session.client("sts")) as sts, closing(session.client("secretsmanager")) as client:
            result = initialize(sts, client)
    except InitializationBlocked as error:
        print(str(error))
        return 1
    except Exception:
        # Never print SDK exception arguments: they can include secret-bearing inputs.
        print("Initialization failed or is uncertain; inspect secret version metadata before retrying. No key material is printed.")
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
