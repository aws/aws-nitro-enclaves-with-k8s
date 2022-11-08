#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

####################################################
# LOAD SETTINGS
####################################################
source $(dirname $0)/utils.sh

####################################################
# AWS CLI
####################################################

OUTPUT=$(aws ecr create-repository \
    --repository-name $ecr_repo_name \
    --image-tag-mutability MUTABLE \
    --region $region)

if [ $? -eq 0 ]; then
    printf "Repository Uri: "
    echo $OUTPUT | jq -r '.repository | .repositoryUri' | tee last_repository.uri
fi
