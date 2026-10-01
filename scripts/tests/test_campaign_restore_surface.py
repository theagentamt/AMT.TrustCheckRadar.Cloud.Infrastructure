import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock

spec = importlib.util.spec_from_file_location('restore_audit', Path(__file__).resolve().parents[1] / 'audit_campaign_restore_surface.py')
audit = importlib.util.module_from_spec(spec); spec.loader.exec_module(audit)


class AuditTests(unittest.TestCase):
    def world(self):
        ddb, backup = Mock(), Mock()
        ddb.describe_table.side_effect = lambda **k: {'Table': {'TableArn': f"arn:aws:dynamodb:{audit.REGION}:{audit.ACCOUNT}:table/{k['TableName']}", 'TableName': k['TableName'], 'TableStatus': 'ACTIVE'}}
        ddb.describe_continuous_backups.return_value = {'ContinuousBackupsDescription': {'PointInTimeRecoveryDescription': {'PointInTimeRecoveryStatus': 'DISABLED'}}}
        ddb.describe_time_to_live.return_value = {'TimeToLiveDescription': {'TimeToLiveStatus': 'ENABLED', 'AttributeName': 'expiresAt'}}
        ddb.list_backups.return_value = {'BackupSummaries': []}
        ddb.list_exports.return_value = {'ExportSummaries': []}
        backup.list_recovery_points_by_resource.return_value = {'RecoveryPoints': []}
        return ddb, backup

    def test_empty_current_inventory_never_approves_history(self):
        ddb, backup = self.world(); r = audit.collect(ddb, backup)
        self.assertTrue(r['metadataComplete']); self.assertFalse(r['historicalCoverageVerified']); self.assertFalse(r['restoreApproved'])
        self.assertEqual(ddb.scan.call_count, 0); self.assertEqual(ddb.get_item.call_count, 0)
        self.assertEqual(set(r['tables']), set(audit.TABLES))
        self.assertTrue(r['tables']['trustcheckradar-dev-campaign-pipeline']['currentBackupPolicyMatches'])
        self.assertEqual(ddb.list_backups.call_args.kwargs['BackupType'], 'ALL')
        self.assertEqual(ddb.list_exports.call_args.kwargs['MaxResults'], 25)

    def test_denied_service_is_not_empty_success(self):
        ddb, backup = self.world(); backup.list_recovery_points_by_resource.side_effect = RuntimeError('private error')
        r = audit.collect(ddb, backup); self.assertFalse(r['metadataComplete']); self.assertNotIn('private error', str(r))
        self.assertFalse(r['tables']['trustcheckradar-dev-campaign-pipeline']['currentBackupPolicyMatches'])

    def test_list_counts_do_not_retain_names_arns_or_tokens(self):
        ddb, backup = self.world()
        ddb.list_exports.return_value = {'ExportSummaries': [{'ExportArn': 'private-export', 'ExportStatus': 'COMPLETED'}], 'NextToken': 'private-cursor'}
        ddb.list_backups.return_value = {'BackupSummaries': [{'BackupName': 'private-name', 'BackupArn': 'private-backup', 'BackupType': 'USER'}]}
        r = audit.collect(ddb, backup, max_pages=2); self.assertFalse(r['metadataComplete']); self.assertNotIn('private-', str(r))
        self.assertEqual(r['tables']['trustcheckradar-dev-campaign-pipeline']['observations']['nativeBackups']['count'], 1)

    def test_identity_mismatch_stops_followup_calls(self):
        ddb, backup = self.world(); ddb.describe_table.return_value = {}; ddb.describe_table.side_effect = None
        r = audit.collect(ddb, backup); self.assertFalse(r['metadataComplete']); self.assertFalse(ddb.list_backups.called); self.assertFalse(backup.mock_calls)

    def test_deadline_and_invalid_bounds(self):
        ddb, backup = self.world(); times=iter([0]+[2]*10)
        r = audit.collect(ddb, backup, seconds=1, clock=lambda: next(times)); self.assertFalse(r['metadataComplete']); self.assertFalse(ddb.mock_calls)
        for kwargs in ({'max_pages': 11}, {'seconds': 121}):
            with self.assertRaises(ValueError): audit.collect(ddb, backup, **kwargs)

    def test_unknown_list_category_remains_incomplete(self):
        ddb, backup = self.world(); ddb.list_exports.return_value = {'ExportSummaries': [{'ExportStatus': 'private-unknown'}]}
        r = audit.collect(ddb, backup); self.assertFalse(r['metadataComplete']); self.assertNotIn('private-unknown', str(r))

    def test_unknown_state_not_recorded_as_disabled(self):
        ddb, backup = self.world(); ddb.describe_continuous_backups.return_value = {'ContinuousBackupsDescription': {'PointInTimeRecoveryDescription': {'PointInTimeRecoveryStatus': 'unknown-private'}}}
        r = audit.collect(ddb, backup); self.assertFalse(r['metadataComplete']); self.assertNotIn('unknown-private', str(r))


if __name__ == '__main__': unittest.main()
