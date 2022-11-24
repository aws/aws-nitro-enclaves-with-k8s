#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# Helper Functions
####################################################

_create_deployment_file() {
  local filepath=$1
  local container_name=$2
  local repository_uri=$3

readonly file_content=$(cat<<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kms-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kms
  template:
    metadata:
      labels:
        app: kms
    spec:
      serviceAccountName: ne-service-account
      containers:
      - name: $container_name
        image: $repository_uri:latest
        command: ["/home/run.sh"]
        imagePullPolicy: Always
        resources:
          limits:
            aws.ec2.nitro/nitro_enclaves: "1"
            hugepages-2Mi: 768Mi
            cpu: 250m
          requests:
            aws.ec2.nitro/nitro_enclaves: "1"
            hugepages-2Mi: 768Mi
        volumeMounts:
        - mountPath: /dev/hugepages
          name: hugepage
          readOnly: false
      volumes:
        - name: hugepage-2mi
        emptyDir:
          medium: HugePages-2Mi
        - name: hugepage-1gi
        emptyDir:
          medium: HugePages-1Gi
      tolerations:
      - effect: NoSchedule
        operator: Exists
      - effect: NoExecute
        operator: Exists
EOF
)

  # Create deployment yaml file
  #
  reset_ifs
  printf '%s\n' $file_content > $filepath || return $FAILURE
  restore_ifs

  return $SUCCESS
}

####################################################
# Events
####################################################

on_run() {
  # Create service account
  eksctl utils associate-iam-oidc-provider \
    --cluster $CONFIG_EKS_CLUSTER_NAME \
    --region $CONFIG_REGION \
    --approve || {
        say_err "Error while creating a service account!"
        return $FAILURE
    }

  local policy_arn=$(aws iam list-policies --query 'Policies[?PolicyName==`enclave_sa_policy`].Arn' --output text)

  if [[ -z "$policy_arn" ]]
  then
    aws iam create-policy \
      --policy-name enclave_sa_policy \
      --policy-document file://$CONTAINER_DIR/kms/enclave_sa_policy.json || {
        say_err "Cannot create IAM policy for KMS!"
        return $FAILURE
    }

    policy_arn=$(aws iam list-policies --query 'Policies[?PolicyName==`enclave_sa_policy`].Arn' --output text)
  fi

  eksctl create iamserviceaccount \
    --name ne-service-account \
    --namespace default \
    --cluster $CONFIG_EKS_CLUSTER_NAME \
    --role-name "kms-service-account" \
    --attach-policy-arn $policy_arn \
    --region $CONFIG_REGION \
    --approve || {
      say_err "Failed to create service account!"
      return $FAILURE
  }

  return $SUCCESS
}

on_file_requested() {
  local filename=$1
  local target_dir=$2
  local retval=$SUCCESS

  case $filename in
  "kms_deployment.yaml")
    local fullpath=$target_dir/$filename
    local container_name=$3;
    local repository_uri=$4;
    _create_deployment_file "$fullpath" "$container_name" "$repository_uri"; retval=$?;
    ;;
  *)
    say_err "${FUNCNAME[0]}: Requested file $1 is unknown."
    retval=$FAILURE
    ;;
  esac

  return $retval
}

on_stop() {
  return $SUCCESS
}