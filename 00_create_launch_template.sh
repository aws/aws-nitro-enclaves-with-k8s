#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

####################################################
# LOAD SETTINGS
####################################################
# ami_id, instance_type
source $(dirname $0)/utils.sh

####################################################
# Launch Template: User Data
####################################################
lt_user_data=$(cat<<"EOF"
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -uxo pipefail

# Test to see if the Nitro enclaves module is loaded
lsmod | grep -q nitro_enclaves
RETURN=${?}

set -e

# Setup Nitro enclave on the host if the module is available as expected.
if [ ${RETURN} -eq 0 ]; then
  yum update -y
  amazon-linux-extras install aws-nitro-enclaves-cli -y
  yum install aws-nitro-enclaves-cli-devel -y
  usermod -aG ne ec2-user
  # usermod -aG ne ssm-user
  usermod -aG ne root
  usermod -aG docker ec2-user
  # usermod -aG docker ssm-user
  usermod -aG docker root
  systemctl start nitro-enclaves-allocator.service
  systemctl enable nitro-enclaves-allocator.service
  systemctl start docker
  systemctl enable docker
  sysctl -w vm.nr_hugepages=2048
  echo "vm.nr_hugepages=2048" >> /etc/sysctl.conf
  chgrp ne /dev/nitro_enclaves
  echo "Done with AWS Nitro enclave Setup"
fi
--==MYBOUNDARY==
EOF
)

####################################################
# Base64 Encode User Data
####################################################

reset_ifs
b64_lt_user_data=$(printf '%s\n' $lt_user_data | base64 -w 0)
restore_ifs

####################################################
# Launch Template Data
####################################################

launch_template_data=$(cat <<EOF
{
  "InstanceType": "${instance_type}",
  "EnclaveOptions": {
    "Enabled": true
  },
  "UserData" : "${b64_lt_user_data}"
}
EOF
)

####################################################
# AWS CLI
####################################################
lt_name=eks_w_ne_$(cat /proc/sys/kernel/random/uuid)
lt_version_desc="Launch an NE-enabled instance with an EKS-optmized AMI."
echo "Creating launch template: ${lt_name}"

OUTPUT=$(aws ec2 create-launch-template \
    --launch-template-name ${lt_name} \
    --version-description  "${lt_version_desc}" \
    --launch-template-data "${launch_template_data}")
   
if [ $? -eq 0 ]; then 
    printf "lt-id: "
    echo $OUTPUT | jq -r '.LaunchTemplate | .LaunchTemplateId' | tee last_launch_template.id
fi

