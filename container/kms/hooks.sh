#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

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

on_podspec_requested() {
  local container_name=$1
  local repo_uri=$2
  local podspec_file=$3

pod_spec=$(cat<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $container_name
spec:
  serviceAccountName: ne-service-account
  containers:
    - name: $container_name
      image: $repo_uri:latest
      command: ["/home/run.sh"]
      imagePullPolicy: Always
      resources:
        limits:
          aws.ec2.nitro/nitro_enclaves: "1"
          hugepages-2Mi: 564Mi
          memory: 2Gi
          cpu: 250m
        requests:
          aws.ec2.nitro/nitro_enclaves: "1"
          hugepages-2Mi: 564Mi
      volumeMounts:
      - mountPath: /dev/hugepages
        name: hugepage
        readOnly: false
  tolerations:
  - effect: NoSchedule
    operator: Exists
  - effect: NoExecute
    operator: Exists
  volumes:
    - name: hugepage
      emptyDir:
        medium: HugePages
EOF
)

  # Create PodSpec yaml file
  reset_ifs
  printf '%s\n' $pod_spec > $podspec_file || return $FAILURE
  restore_ifs

  return $SUCCESS
}

on_stop() {
  return $SUCCESS
}