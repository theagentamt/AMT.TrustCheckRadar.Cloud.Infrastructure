"""Read-only, metadata-only Dev token-store inventory. Never reads token items."""
import argparse
import datetime
import json

ACCOUNT = "107827791950"
REGION = "us-east-1"
TABLE = "trustcheckradar-dev-play-tokens"
ARN = f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{TABLE}"


def audit(session):
    if session.client("sts").get_caller_identity()["Account"] != ACCOUNT:
        raise ValueError("Unexpected AWS account")
    ddb, backup, iam = (session.client(name, region_name=REGION) for name in ("dynamodb", "backup", "iam"))
    report = {"observedAtUtc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "table": TABLE,
              "scope": "Metadata only; no token, binding or account items read", "tableExists": False}
    try:
        table = ddb.describe_table(TableName=TABLE)["Table"]
    except ddb.exceptions.ResourceNotFoundException:
        table = None
    if table:
        report.update(tableExists=True, tableStatus=table["TableStatus"],
                      streamEnabled=table.get("StreamSpecification", {}).get("StreamEnabled", False),
                      deletionProtection=table.get("DeletionProtectionEnabled", False),
                      indexProjections={x["IndexName"]: x["Projection"]["ProjectionType"] for x in table.get("GlobalSecondaryIndexes", [])},
                      ttl=ddb.describe_time_to_live(TableName=TABLE)["TimeToLiveDescription"],
                      pitrStatus=ddb.describe_continuous_backups(TableName=TABLE)["ContinuousBackupsDescription"]["PointInTimeRecoveryDescription"]["PointInTimeRecoveryStatus"])
        report["tablePolicy"] = json.loads(ddb.get_resource_policy(ResourceArn=ARN)["Policy"])
        backups=[]; cursor=None
        while True:
            page=ddb.list_backups(TableName=TABLE, **({"ExclusiveStartBackupArn":cursor} if cursor else {}))
            backups.extend(page.get("BackupSummaries", []));cursor=page.get("LastEvaluatedBackupArn")
            if not cursor:break
        report["dynamoBackupCount"]=len(backups)
        points=[];cursor=None
        while True:
            page=backup.list_recovery_points_by_resource(ResourceArn=ARN, **({"NextToken":cursor} if cursor else {}))
            points.extend(page.get("RecoveryPoints", []));cursor=page.get("NextToken")
            if not cursor:break
        report["awsBackupRecoveryPointCount"]=len(points)
    plans=[]
    for page in backup.get_paginator("list_backup_plans").paginate():
        for plan in page["BackupPlansList"]:
            selections=[]
            for section in backup.get_paginator("list_backup_selections").paginate(BackupPlanId=plan["BackupPlanId"]):
                for selection in section["BackupSelectionsList"]:
                    selections.append(backup.get_backup_selection(BackupPlanId=plan["BackupPlanId"], SelectionId=selection["SelectionId"])["BackupSelection"])
            plans.append({"id":plan["BackupPlanId"],"selections":selections})
    report["backupPlans"]=plans
    report["backupExecutionRoles"]=[r["Arn"] for page in iam.get_paginator("list_roles").paginate() for r in page["Roles"] if "backup.amazonaws.com" in json.dumps(r["AssumeRolePolicyDocument"])]
    report["configurationReviewRequired"]=bool(plans or report["backupExecutionRoles"])
    report["limitations"]=["Point-in-time metadata inventory; future backup configuration requires requalification.",
                            "This audit does not prove explicit expiry/account deletion or runtime activation readiness.",
                            "Table resource policy does not by itself govern AWS Backup StartAwsBackupJob; inspect actual execution-role denies when present."]
    return report


def main():
    import boto3
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default="trustcheckradar")
    parser.add_argument("--output", required=True)
    args=parser.parse_args()
    report=audit(boto3.Session(profile_name=args.profile, region_name=REGION))
    with open(args.output,"w") as stream:json.dump(report,stream,indent=2);stream.write("\n")
    print(json.dumps({k:report[k] for k in ("table","tableExists","configurationReviewRequired")}))


if __name__ == "__main__":
    main()
