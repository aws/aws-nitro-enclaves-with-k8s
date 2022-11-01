#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

####################################################
# LOAD SETTINGS
####################################################
source $(dirname $0)/utils.sh

####################################################
# Run the pod
####################################################
kubectl describe pod $ecr_repo_name
echo "-----------------------------------------------------------------------------------------"
kubectl logs $ecr_repo_name
