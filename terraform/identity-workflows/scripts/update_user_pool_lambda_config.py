#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
import tempfile


ALLOWED_UPDATE_FIELDS = [
    "Policies",
    "DeletionProtection",
    "LambdaConfig",
    "AutoVerifiedAttributes",
    "SmsVerificationMessage",
    "EmailVerificationMessage",
    "EmailVerificationSubject",
    "VerificationMessageTemplate",
    "SmsAuthenticationMessage",
    "UserAttributeUpdateSettings",
    "MfaConfiguration",
    "DeviceConfiguration",
    "EmailConfiguration",
    "SmsConfiguration",
    "UserPoolTags",
    "AdminCreateUserConfig",
    "UserPoolAddOns",
    "AccountRecoverySetting",
    "PoolName",
    "UserPoolTier",
]


def run_aws(args, env):
    result = subprocess.run(
        ["aws", *args],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "aws command failed")
    return result.stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--user-pool-id", required=True)
    parser.add_argument("--post-confirmation-arn", required=True)
    parser.add_argument("--region", required=True)
    parser.add_argument("--overrides-json", default="{}")
    parser.add_argument("--profile", default=None)
    args = parser.parse_args()

    env = os.environ.copy()
    env["AWS_REGION"] = args.region
    env["AWS_DEFAULT_REGION"] = args.region
    if args.profile:
        env["AWS_PROFILE"] = args.profile

    raw = run_aws(
        ["cognito-idp", "describe-user-pool", "--user-pool-id", args.user_pool_id],
        env,
    )
    described = json.loads(raw)["UserPool"]

    payload = {"UserPoolId": args.user_pool_id}
    for key in ALLOWED_UPDATE_FIELDS:
        if key in described and described[key] is not None:
            payload[key] = described[key]

    overrides = json.loads(args.overrides_json)
    lambda_config = dict(payload.get("LambdaConfig") or {})
    lambda_config.update(overrides)
    lambda_config["PostConfirmation"] = args.post_confirmation_arn
    payload["LambdaConfig"] = lambda_config

    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(payload, handle)
        temp_path = handle.name

    try:
        run_aws(
            ["cognito-idp", "update-user-pool", "--cli-input-json", f"file://{temp_path}"],
            env,
        )
    finally:
        try:
            os.unlink(temp_path)
        except OSError:
            pass


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
