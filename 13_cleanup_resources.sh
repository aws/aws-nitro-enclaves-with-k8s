#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

####################################################
# LOAD SETTINGS
####################################################
source $(dirname $0)/utils.sh

####################################################
# AWS CLI
####################################################

aws ecr delete-repository \
    --repository-name $ecr_repo_name --force

rm -f last_repository.uri
