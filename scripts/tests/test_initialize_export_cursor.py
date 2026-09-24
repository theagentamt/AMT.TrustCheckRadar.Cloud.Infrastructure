import base64
from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch
from types import SimpleNamespace

SPEC = importlib.util.spec_from_file_location("initializer", Path(__file__).resolve().parents[1] / "initialize_export_cursor.py")
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)
ARN = f"arn:aws:secretsmanager:{module.REGION}:{module.ACCOUNT}:secret:{module.NAME}-AbC123"


class Sts:
    def __init__(self, account=module.ACCOUNT):
        self.account = account

    def get_caller_identity(self):
        return {"Account": self.account}


class Secret:
    def __init__(self, *, existing=False, concurrent=False, late_race=False, automatic=True):
        self.versions = {"existing": []} if existing else {}
        self.concurrent, self.late_race, self.automatic = concurrent, late_race, automatic
        self.calls, self.payload = [], None

    def describe_secret(self, **kwargs):
        return {"ARN": ARN, "VersionIdsToStages": self.versions}

    def list_secret_version_ids(self, **kwargs):
        assert kwargs["IncludeDeprecated"] is True
        return {"Versions": [{"VersionId": v} for v in self.versions]}

    def put_secret_value(self, **kwargs):
        self.calls.append(("put", {k: v for k, v in kwargs.items() if k != "SecretString"}))
        self.payload = kwargs["SecretString"]
        version = kwargs["ClientRequestToken"]
        self.versions[version] = list(kwargs["VersionStages"])
        if self.concurrent:
            self.versions["other"] = ["AWSCURRENT"]
        elif self.automatic:
            self.versions[version].append("AWSCURRENT")
        return {"VersionId": version}

    def update_secret_version_stage(self, **kwargs):
        self.calls.append(("stage", kwargs))
        if kwargs["VersionStage"] == "AWSCURRENT":
            assert "RemoveFromVersionId" not in kwargs
            if self.late_race:
                self.versions["other"] = ["AWSCURRENT"]
                raise RuntimeError("Concurrent current label; AWS rejects missing RemoveFromVersionId")
            self.versions[kwargs["MoveToVersionId"]].append("AWSCURRENT")
        else:
            self.versions[kwargs["RemoveFromVersionId"]].remove(kwargs["VersionStage"])

    def get_secret_value(self, **kwargs):
        assert kwargs["VersionStage"] == "AWSCURRENT"
        assert "AWSCURRENT" in self.versions[kwargs["VersionId"]]
        return {"VersionId": kwargs["VersionId"], "SecretString": self.payload}


class InitializationTests(unittest.TestCase):
    def test_cli_closes_sdk_clients_without_context_manager_support(self):
        sts, secret = Sts(), Secret()
        closed = []
        sts.close = lambda: closed.append("sts")
        secret.close = lambda: closed.append("secret")
        session = SimpleNamespace(client=lambda service: sts if service == "sts" else secret)
        fake_sdk = SimpleNamespace(Session=lambda **kwargs: session)
        output = io.StringIO()
        with patch.dict("sys.modules", {"boto3": fake_sdk}), patch("sys.argv", ["initializer"]), redirect_stdout(output):
            self.assertEqual(module.main(), 0)
        self.assertEqual(closed, ["secret", "sts"])
        self.assertTrue(json.loads(output.getvalue())["currentVerified"])
        self.assertNotIn(json.loads(secret.payload)["keys"]["k1"], output.getvalue())

    def test_generated_key_is_valid_and_result_contains_no_key(self):
        client = Secret()
        result = module.initialize(Sts(), client)
        ring = json.loads(client.payload)
        self.assertEqual(set(ring), {"activeKeyId", "keys"})
        self.assertEqual(ring["activeKeyId"], "k1")
        key = ring["keys"]["k1"]
        self.assertEqual(len(base64.b64decode(key, validate=True)), 32)
        self.assertNotIn(key, json.dumps(result))
        self.assertEqual(client.versions[result["versionId"]], ["AWSCURRENT"])
        self.assertFalse(result["runtimeActivated"])

    def test_existing_even_deprecated_version_blocks_writes(self):
        client = Secret(existing=True)
        with self.assertRaises(module.InitializationBlocked):
            module.initialize(Sts(), client)
        self.assertEqual(client.calls, [])

    def test_wrong_account_stops_before_any_secret_access(self):
        with self.assertRaises(module.InitializationBlocked):
            module.initialize(Sts("999999999999"), object())

    def test_concurrent_current_is_never_replaced(self):
        client = Secret(concurrent=True)
        with self.assertRaises(module.InitializationBlocked):
            module.initialize(Sts(), client)
        self.assertEqual([op for op, _ in client.calls], ["put"])
        self.assertEqual(client.versions["other"], ["AWSCURRENT"])
        self.assertNotIn("AWSCURRENT", client.calls[0][1]["VersionStages"])

    def test_absent_current_promoted_without_removing_other_version(self):
        client = Secret(automatic=False)
        result = module.initialize(Sts(), client)
        self.assertEqual(client.versions[result["versionId"]], ["AWSCURRENT"])
        promotion = client.calls[1][1]
        self.assertNotIn("RemoveFromVersionId", promotion)

    def test_race_at_promotion_preserves_the_winner(self):
        client = Secret(automatic=False, late_race=True)
        with self.assertRaises(RuntimeError):
            module.initialize(Sts(), client)
        self.assertEqual(client.versions["other"], ["AWSCURRENT"])
        self.assertEqual(len(client.calls), 2)


if __name__ == "__main__":
    unittest.main()
