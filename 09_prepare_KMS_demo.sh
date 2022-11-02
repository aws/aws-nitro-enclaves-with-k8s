#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

####################################################
# LOAD SETTINGS
####################################################
source $(dirname $0)/utils.sh

####################################################
# Create service account
####################################################
eksctl utils associate-iam-oidc-provider \
    --cluster $cluster_name \
    --approve

POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`enclave_sa_policy`].Arn' --output text)
if [[ -z "$POLICY_ARN" ]]
then
    aws iam create-policy \
        --policy-name enclave_sa_policy \
        --policy-document file://container/enclave_sa_policy.json
    POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`enclave_sa_policy`].Arn' --output text)
fi
echo $POLICY_ARN

eksctl create iamserviceaccount \
    --name ne-service-account \
    --namespace default \
    --cluster $cluster_name \
    --role-name "kms-service-account" \
    --attach-policy-arn $POLICY_ARN \
    --approve

####################################################
# AWS ECR
####################################################

OUTPUT=$(aws ecr create-repository \
    --repository-name $ecr_kms_repo_name \
    --image-tag-mutability MUTABLE \
    --region $region)

if [ $? -eq 0 ]; then
    printf "Repository Uri: "
    echo $OUTPUT | jq -r '.repository | .repositoryUri' | tee last_kms_repository.uri
fi

ecr_kms_repo_uri=$(cat last_kms_repository.uri)
ecr_repo_addr=$(echo $ecr_kms_repo_uri | cut -d '/' -f1)
dockerfile_path=$(dirname $0)/container

####################################################
# AWS CLI
####################################################

aws ecr get-login-password \
	--region $region | docker login --username AWS --password-stdin $ecr_repo_addr

####################################################
# Docker
####################################################

docker image rm $ecr_kms_repo_name:latest
docker build -t $ecr_kms_repo_name:latest -f $dockerfile_path/KMS.dockerfile $dockerfile_path
docker tag $ecr_kms_repo_name:latest $ecr_kms_repo_uri
docker push $ecr_kms_repo_uri