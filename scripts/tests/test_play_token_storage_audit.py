import unittest
from scripts.audit_play_token_storage import may_trust_backup, needs_review

class AuditTests(unittest.TestCase):
    def test_wildcard_trust_requires_review_even_with_conditions(self):
        for principal in ["*", {"Service":"*"}, {"Service":["lambda.amazonaws.com","backup.amazonaws.com"]}]:
            self.assertTrue(may_trust_backup({"Statement":[{"Effect":"Allow","Principal":principal,"Condition":{"StringEquals":{"aws:SourceAccount":"107827791950"}}}]}))
        self.assertFalse(may_trust_backup({"Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"}}]}))
        self.assertFalse(may_trust_backup({"Statement":[{"Effect":"Deny","Principal":"*"}]}))

    def test_observed_copies_and_storage_violations_never_report_clear(self):
        baseline={"backupPlans":[],"backupExecutionRoles":[],"tableExists":True,"pitrStatus":"DISABLED","streamEnabled":False,"deletionProtection":True,"indexProjections":{"GSI1":"KEYS_ONLY"},"ttl":{"TimeToLiveStatus":"ENABLED","AttributeName":"expiresAt"}}
        self.assertFalse(needs_review(baseline))
        for change in [{"dynamoBackupCount":1},{"awsBackupRecoveryPointCount":1},{"pitrStatus":"ENABLED"},{"streamEnabled":True},{"indexProjections":{"GSI1":"ALL"}},{"ttl":{"TimeToLiveStatus":"DISABLED"}},{"backupExecutionRoles":["wildcard-trust"]}]:
            self.assertTrue(needs_review(baseline|change),change)
