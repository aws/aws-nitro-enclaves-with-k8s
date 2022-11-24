#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# Launch Template: User Data
####################################################

readonly lt_user_data=$(cat<<EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash -e
readonly NE_ALLOCATOR_SPEC_PATH="/etc/nitro_enclaves/allocator.yaml"
# Node resources that will be allocated for Nitro Enclaves
readonly CPU_COUNT=$CONFIG_NODE_ENCLAVE_CPU_LIMIT
readonly MEMORY_MIB=$CONFIG_NODE_ENCLAVE_MEMORY_LIMIT_MIB

# This step below is needed to install nitro-enclaves-allocator service.
amazon-linux-extras install aws-nitro-enclaves-cli -y
# Update enclave's allocator specification: allocator.yaml
sed -i "s/cpu_count:.*/cpu_count: \$CPU_COUNT/g" \$NE_ALLOCATOR_SPEC_PATH
sed -i "s/memory_mib:.*/memory_mib: \$MEMORY_MIB/g" \$NE_ALLOCATOR_SPEC_PATH
# Restart the nitro-enclaves-allocator service to take changes effect.
systemctl restart nitro-enclaves-allocator.service
echo "NE user data script has finished successfully."
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
