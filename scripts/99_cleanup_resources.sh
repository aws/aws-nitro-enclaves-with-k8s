#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# Helper functions
####################################################

delete_file() {
 say "Deleting $1..."
 rm -f $WORKING_DIR/$1
}

####################################################
# Main
####################################################

main() {
  #TODO: Delete the ECR repository
  #TODO: Delete docker images

  say "Attempt to delete cluster node group: $CONFIG_EKS_WORKER_NODE_NAME"

  eksctl delete nodegroup --cluster=$CONFIG_EKS_CLUSTER_NAME --name=$CONFIG_EKS_WORKER_NODE_NAME \
    --region $CONFIG_REGION || $FLAG_IGNORE_ERRORS || {
      say_err "Cluster node group cannot be deleted."
      return $FAILURE
    }

  say "Attempt to delete cluster: $CONFIG_EKS_WORKER_NODE_NAME"

  eksctl delete cluster --name $CONFIG_EKS_CLUSTER_NAME \
    --region $CONFIG_REGION || $FLAG_IGNORE_ERRORS || {
      say_err "Cluster cannot be deleted."
      return $FAILURE
    }

  local lt_name="lt_$CONFIG_SETUP_UUID"
  local lt_id=$(get_launch_template_id $lt_name)

  say "Attempt to delete launch template: $lt_name"

  [[ "$lt_id" != "" ]] && {
    awscli ec2 delete-launch-template --launch-template-id $lt_id || $FLAG_IGNORE_ERRORS || \
      --region $CONFIG_REGION || $FLAG_IGNORE_ERRORS || {
        say_error "Launch template cannot be deleted."
        return $FAILURE
      }
  }

  delete_file $FILE_CLUSTER_CONFIG
  delete_file $FILE_CONFIGURATION
  delete_file $FILE_SETUP_ID
}