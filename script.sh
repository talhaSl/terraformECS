#!/bin/bash

SOURCE_REGION="us-east-1"
DESTINATION_REGION="us-west-2"

# Get a list of all EC2 instances in the source region
INSTANCE_IDS=$(aws ec2 describe-instances --region $SOURCE_REGION --query 'Reservations[*].Instances[*].InstanceId' --output text)

# Iterate over each instance and create/copy snapshots
for INSTANCE_ID in $INSTANCE_IDS; do
    echo "Processing EC2 instance: $INSTANCE_ID"

    # Get the EC2 instance name
    INSTANCE_NAME=$(aws ec2 describe-instances --region $SOURCE_REGION --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value' --output text)

    # Create a timestamp in the format year-month-day
    TIMESTAMP=$(date +"%Y-%m-%d")

    # Create a new snapshot for the specified EC2 instance in the source region
    NEW_SNAPSHOT_NAME="Snapshot_${INSTANCE_NAME}_${TIMESTAMP}"
    
    echo "Creating a new snapshot for EC2 instance $INSTANCE_ID ($INSTANCE_NAME) in $SOURCE_REGION..."
    SNAPSHOT_RESULT=$(aws ec2 create-snapshot --region $SOURCE_REGION --volume-id $(aws ec2 describe-instances --region $SOURCE_REGION --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].BlockDeviceMappings[*].Ebs.VolumeId' --output text) --description "$NEW_SNAPSHOT_NAME")

    # Extract the new snapshot ID from the creation result
    SNAPSHOT_ID=$(echo "$SNAPSHOT_RESULT" | grep -oP '(?<="SnapshotId": ")[^"]+')

    if [ -z "$SNAPSHOT_ID" ]; then
        echo "Error creating snapshot for EC2 instance $INSTANCE_ID in $SOURCE_REGION"
        continue
    fi

    echo "Snapshot created for EC2 instance $INSTANCE_ID ($INSTANCE_NAME) in $SOURCE_REGION with ID: $SNAPSHOT_ID"

    # Copy the newly created snapshot to the destination region
    NEW_COPY_SNAPSHOT_NAME="Copied_Snapshot_${INSTANCE_NAME}_${TIMESTAMP}"
    echo "Copying snapshot $SNAPSHOT_ID from $SOURCE_REGION to $DESTINATION_REGION..."
    COPY_RESULT=$(aws ec2 copy-snapshot --region $DESTINATION_REGION --source-region $SOURCE_REGION --source-snapshot-id $SNAPSHOT_ID --description "$NEW_COPY_SNAPSHOT_NAME")

    # Extract the new snapshot ID from the copy result
    NEW_SNAPSHOT_ID=$(echo "$COPY_RESULT" | grep -oP '(?<="SnapshotId": ")[^"]+')

    if [ -z "$NEW_SNAPSHOT_ID" ]; then
        echo "Error during snapshot copy to $DESTINATION_REGION for snapshot $SNAPSHOT_ID"
        continue
    fi

    echo "Snapshot $SNAPSHOT_ID copied to $DESTINATION_REGION with new ID: $NEW_SNAPSHOT_ID and name: $NEW_COPY_SNAPSHOT_NAME"
done

echo "Snapshot copy process completed for all EC2 instances."
