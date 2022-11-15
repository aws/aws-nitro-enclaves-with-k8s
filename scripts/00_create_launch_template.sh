#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# Launch Template: User Data
####################################################

readonly lt_user_data=$(cat<<"EOF"
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
  usermod -aG ne root
  usermod -aG docker ec2-user
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
readonly b64_lt_user_data=$(printf '%s\n' $lt_user_data | base64 -w 0)
restore_ifs

####################################################
# Launch Template Data
####################################################

readonly launch_template_data=$(cat <<EOF
{
  "InstanceType": "$CONFIG_INSTANCE_TYPE",
  "EnclaveOptions": {
    "Enabled": true
  },
  "UserData" : "${b64_lt_user_data}"
}
EOF
)

####################################################
# Helper functions
####################################################

launch_template_exists() {
  local name=$1
  local out=$(awscli ec2 describe-launch-templates | grep $name)
  ok_or_die "Cannot get launch template info!"
  if [[ -z "$out" ]]; then
    return 255 # Not exists.
  fi
}

create_launch_template() {
  local name=$1

  awscli ec2 create-launch-template \
    --launch-template-name $name \
    --version-description  "$lt_version_desc" \
    --launch-template-data "$launch_template_data"
}

####################################################
# Functions
####################################################

main() {
  local lt_name="lt_$CONFIG_SETUP_UUID"

  launch_template_exists $lt_name -eq 0 && {
    say_warn "A launch template with name $lt_name already exists."
    return $SUCCESS
  }

  say "Creating launch template with name: ${lt_name}"

  create_launch_template $lt_name || {
    say_err "Error while creating launch template! (Code: $?)"
    return $FAILURE
  }

  say "Launch template has been created successfully in $CONFIG_REGION region."
}
