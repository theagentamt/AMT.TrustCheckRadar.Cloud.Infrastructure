import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("campaign_audit", Path(__file__).resolve().parents[1] / "audit_campaign_repair_counts.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class Client:
    def __init__(self, repeat=False, items=False):
        self.requests = []
        self.repeat, self.items = repeat, items

    def describe_table(self, **kwargs):
        return {"Table": {"TableArn": "arn:aws:dynamodb:us-east-1:107827791950:table/fixture"}}

    def scan(self, **kwargs):
        self.requests.append(kwargs)
        result = {"Count": 1, "ScannedCount": 2}
        if self.repeat:
            result["LastEvaluatedKey"] = {"PK": {"S": "synthetic-cursor-never-persist"}}
        if self.items:
            result["Items"] = []
        return result


def run(client, **kwargs):
    return audit.collect(client, account="107827791950", region="us-east-1", table="fixture", **kwargs)


class CountsTest(unittest.TestCase):
    def test_only_counts_no_projection_or_values_are_returned(self):
        client = Client()
        result = run(client)
        self.assertTrue(result["allTraversalsComplete"])
        self.assertEqual(len(client.requests), 4)
        for request in client.requests:
            self.assertEqual(request["Select"], "COUNT")
            self.assertTrue(request["ConsistentRead"])
            self.assertNotIn("ProjectionExpression", request)
        self.assertFalse(result["inventoryApproved"])
        self.assertFalse(result["erasureVerified"])

    def test_page_bound_cannot_look_like_complete_inventory(self):
        client = Client(repeat=True)
        result = run(client, max_pages=2)
        self.assertEqual(len(client.requests), 8)
        self.assertFalse(result["allTraversalsComplete"])
        self.assertTrue(all(v["stopReason"] == "page_budget" for v in result["counts"].values()))
        self.assertNotIn("synthetic-cursor-never-persist", str(result))

    def test_time_budget_prevents_following_scans(self):
        values = iter([0, 2, 2, 2, 2])
        client = Client()
        result = run(client, seconds=1, monotonic=lambda: next(values))
        self.assertFalse(result["allTraversalsComplete"])
        self.assertEqual(client.requests, [])

    def test_wrong_table_or_item_response_fails_closed(self):
        client = Client()
        with self.assertRaises(audit.AuditError):
            audit.collect(client, account="000000000000", region="us-east-1", table="fixture")
        self.assertEqual(client.requests, [])
        with self.assertRaises(audit.AuditError):
            run(Client(items=True))


if __name__ == "__main__":
    unittest.main()
