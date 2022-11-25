#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# EKSCTL ClusterConfig generation
####################################################

function generate_cluster_config() {
local lt_id=$1
cat<<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $CONFIG_EKS_CLUSTER_NAME
  region: $CONFIG_REGION
  version: "$CONFIG_K8S_VERSION"

managedNodeGroups:
  - name: $CONFIG_EKS_WORKER_NODE_NAME
    launchTemplate:
      id: $lt_id
      version: "1"
    desiredCapacity: $CONFIG_EKS_WORKER_NODE_CAPACITY

EOF
}

####################################################
# Main
####################################################

main() {
  local lt_name="lt_$CONFIG_SETUP_UUID"
  local lt_id=$(get_launch_template_id $lt_name)

  [[ "$lt_id" != "" ]] || die "Cannot retrieve launch template id!"
  debug "Launch template id: $lt_id"

  cluster_exists $CONFIG_EKS_CLUSTER_NAME -eq 0 && {
    say_warn "The EKS cluster with name $CONFIG_EKS_CLUSTER_NAME already exists."
    return $SUCCESS
  }

  local cluster_config=$(generate_cluster_config $lt_id)

  say_warn "####################################################"
  say_warn "Using $FILE_CLUSTER_CONFIG to create an EKS cluster."
  say_warn "Cluster creation will take some time."
  say_warn "####################################################"

  reset_ifs
  printf '%s\n' $cluster_config > $WORKING_DIR/$FILE_CLUSTER_CONFIG
  restore_ifs

  debug $cluster_config
  eksctl create cluster -f $WORKING_DIR/$FILE_CLUSTER_CONFIG
}
