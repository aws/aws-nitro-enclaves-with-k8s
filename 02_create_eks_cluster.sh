#!/bin/bash -e
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

####################################################
# LOAD SETTINGS
####################################################
source $(dirname $0)/utils.sh

lt_id=$(cat last_launch_template.id)
cluster_config_file=""

####################################################
# EXIT_HANDLER
####################################################
function on_exit {
  if [ "$cluster_config_file" != "" ]; then
    echo "Removing temporary cluster config file $cluster_config_file"
    rm -f $cluster_config_file
  fi
}

trap on_exit EXIT

####################################################
# EKSCTL ClusterConfig
####################################################

cluster_config=$(cat<<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $cluster_name
  region: $region
  version: "${k8s_version}"

managedNodeGroups:
  - name: $managed_wg_name
    launchTemplate:
      id: $lt_id 
      version: "1"
    desiredCapacity: 1

EOF
)

cluster_config_file=/tmp/eks_cc_$(cat /proc/sys/kernel/random/uuid).yaml
echo "##############################################################"
echo "Using $cluster_config_file to create cluster. Cluster creation operation will take 15-20 minutes."
echo "##############################################################"

_IFS=$IFS
IFS=
printf '%s\n' $cluster_config  > $cluster_config_file
IFS=$_IFS
cat $cluster_config_file

####################################################
# EKSCTL cluster creation
####################################################
eksctl create cluster -f $cluster_config_file
