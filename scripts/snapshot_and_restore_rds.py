import boto3
import sys
from datetime import datetime, timezone

def find_rds_instance_by_host(rds_client, host):
    paginator = rds_client.get_paginator('describe_db_instances')
    for page in paginator.paginate():
        for db in page['DBInstances']:
            if db['Endpoint']['Address'] == host:
                return db
    return None

def create_snapshot_and_wait(rds_client, db_instance_identifier):
    snapshot_identifier = f"{db_instance_identifier}-snapshot-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}"
    print(f"\n=== Creating Snapshot ===")
    print(f"[INFO] Creating snapshot: {snapshot_identifier}")
    
    rds_client.create_db_snapshot(
        DBInstanceIdentifier=db_instance_identifier,
        DBSnapshotIdentifier=snapshot_identifier
    )

    print("[INFO] Waiting for snapshot to become available...")
    waiter = rds_client.get_waiter('db_snapshot_available')
    waiter.wait(
        DBSnapshotIdentifier=snapshot_identifier,
        WaiterConfig={'Delay': 15, 'MaxAttempts': 40}
    )

    print(f"[SUCCESS] Snapshot available: {snapshot_identifier}")
    return snapshot_identifier

def restore_snapshot_with_config(rds_client, snapshot_id, original_db, new_db_identifier):
    print(f"\n=== Restoring Snapshot ===")
    print(f"[INFO] Restoring snapshot '{snapshot_id}' as new DB instance '{new_db_identifier}'")

    restore_params = {
        'DBInstanceIdentifier': new_db_identifier,
        'DBSnapshotIdentifier': snapshot_id,
        'DBInstanceClass': original_db['DBInstanceClass'],
        'MultiAZ': original_db['MultiAZ'],
        'PubliclyAccessible': original_db['PubliclyAccessible'],
        'StorageType': original_db['StorageType'],
        'VpcSecurityGroupIds': [sg['VpcSecurityGroupId'] for sg in original_db['VpcSecurityGroups']],
        'DBSubnetGroupName': original_db['DBSubnetGroup']['DBSubnetGroupName'],
        'AvailabilityZone': original_db['AvailabilityZone'],
        'Tags': [{'Key': 'RestoredFrom', 'Value': original_db['DBInstanceIdentifier']}],
        'CopyTagsToSnapshot': True,
        'DeletionProtection': False
    }

    if 'DBParameterGroups' in original_db:
        restore_params['DBParameterGroupName'] = original_db['DBParameterGroups'][0]['DBParameterGroupName']
    if 'OptionGroupMemberships' in original_db:
        restore_params['OptionGroupName'] = original_db['OptionGroupMemberships'][0]['OptionGroupName']

    rds_client.restore_db_instance_from_db_snapshot(**restore_params)

    print("[INFO] Waiting for the new DB instance to be available...")
    waiter = rds_client.get_waiter('db_instance_available')
    waiter.wait(
        DBInstanceIdentifier=new_db_identifier,
        WaiterConfig={'Delay': 20, 'MaxAttempts': 60}
    )

    print(f"[SUCCESS] New DB instance '{new_db_identifier}' is now available.")
    
    response = rds_client.describe_db_instances(DBInstanceIdentifier=new_db_identifier)
    new_db = response['DBInstances'][0]
    endpoint = new_db['Endpoint']['Address']
    print(f"[INFO] Endpoint: {endpoint}")
    return endpoint

def main():
    if len(sys.argv) != 4:
        print("Usage: python snapshot_and_restore_rds.py <original-db-host> <new-db-name> <region>")
        sys.exit(1)

    original_host = sys.argv[1]
    new_db_name = sys.argv[2]
    region = sys.argv[3]

    rds_client = boto3.client('rds', region_name=region)

    print(f"\n=== Snapshot and Restore Process ===")

    original_db = find_rds_instance_by_host(rds_client, original_host)
    print(f"[INFO] Searching for DB instance with host: {original_host}")
    if not original_db:
        print(f"[ERROR] Could not find DB instance with host: {original_host}")
        sys.exit(1)

    db_identifier = original_db['DBInstanceIdentifier']
    snapshot_id = create_snapshot_and_wait(rds_client, db_identifier)
    new_host = restore_snapshot_with_config(rds_client, snapshot_id, original_db, new_db_name)

    return new_host

if __name__ == "__main__":
    main()