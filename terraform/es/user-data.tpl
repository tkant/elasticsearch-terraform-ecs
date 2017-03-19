#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo ECS_CLUSTER="${ecs_name}" >> /etc/ecs/ecs.config
PATH=$PATH:/usr/local/bin
# Instance should be added to an security group that allows HTTP outbound
yum update
# Install jq, a JSON parser
yum -y install jq
# Install NFS client
if ! rpm -qa | grep -qw nfs-utils; then
    yum -y install nfs-utils
fi
if ! rpm -qa | grep -qw python27; then
    yum -y install python27
fi
# Install pip
yum -y install python27-pip
# Install awscli
pip install awscli
# Upgrade to the latest version of the awscli
# pip install --upgrade awscli
# Add support for EFS to the CLI configuration
aws configure set preview.efs true
#Get region of EC2 from instance metadata
EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
#Create mount point
mkdir /mnt/efs
echo Mounting directory 
#Get EFS FileSystemID attribute
#Instance needs to be added to a EC2 role that give the instance at least read access to EFS
EFS_FILE_SYSTEM_ID="${efs_file_system_id}"
# Check to see if the variable is set. If not, then exit.
if [-z "$EFS_FILE_SYSTEM_ID"]; then
    echo "ERROR: variable not set" 1> /etc/efssetup.log
    exit
fi
# Instance needs to be a member of security group that allows 2049 inbound/outbound
# The security group that the instance belongs to has to be added to EFS file system configuration
# Create variables for source and target
DIR_SRC=$EFS_FILE_SYSTEM_ID.efs.$EC2_REGION.amazonaws.com
DIR_TGT=/mnt/efs 
echo Mounting $DIR_SRC:/ to $DIR_TGT
# Mount EFS file system
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 $DIR_SRC:/ $DIR_TGT
chmod go+rw $DIR_TGT
# Backup fstab
cp -p /etc/fstab /etc/fstab.back-$(date +%F)
# Append line to fstab
echo -e "$DIR_SRC:/ \t\t $DIR_TGT \t\t nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0" | tee -a /etc/fstab