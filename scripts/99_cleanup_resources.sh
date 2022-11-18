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

# Deletes the CloudFormation stack created by eksctl
#
delete_eksctl_cf_stack() {
  local cluster_name=$1
  local stack_name="eksctl-$cluster_name-cluster"
  local out=$(aws cloudformation describe-stacks --region $CONFIG_REGION | jq -r --arg sn "$stack_name" \
   '.Stacks[]|select(.StackName==$sn)|.StackName')

  [[ "$out" == "$stack_name" ]] && {
      say_warn "Attempt to delete cloud formation stack created by eksctl..."
      aws cloudformation delete-stack --stack-name $stack_name --region $CONFIG_REGION && {
      return $SUCCESS
    }
  }

  say_err "Cannot delete cloud formation stack: $stack_name"
  return $FAILURE
}

####################################################
# Main
####################################################

main() {
  #TODO: Delete the ECR repository
  #TODO: Delete docker images

  say "Attempt to delete cluster node group: $CONFIG_EKS_WORKER_NODE_NAME"

  local cf_stack_delete=false
  eksctl delete nodegroup --cluster=$CONFIG_EKS_CLUSTER_NAME --name=$CONFIG_EKS_WORKER_NODE_NAME \
    --region $CONFIG_REGION || $FLAG_IGNORE_ERRORS || {
      say_warn "Cluster node group cannot be deleted. Trying to delete CloudFormation stack..."
      delete_eksctl_cf_stack $CONFIG_EKS_CLUSTER_NAME && {
        say "CloudFormation deletion has been triggered successfully!"
        cf_stack_delete=true
      }
    }

  [[ "$cf_stack_delete" != true ]] && {
    say "Attempt to delete cluster: $CONFIG_EKS_WORKER_NODE_NAME"

    eksctl delete cluster --name $CONFIG_EKS_CLUSTER_NAME \
      --region $CONFIG_REGION || $FLAG_IGNORE_ERRORS || {
        say_err "Cluster cannot be deleted."
        return $FAILURE
      }
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