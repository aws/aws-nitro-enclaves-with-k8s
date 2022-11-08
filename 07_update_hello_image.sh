#!/bin/bash -e
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

####################################################
# LOAD SETTINGS
####################################################
source $(dirname $0)/utils.sh
ecr_repo_uri=$(cat last_repository.uri) #e.g. 99999999999.dkr.ecr.eu-central-1.amazonaws.com/hello-nitro-enclaves
ecr_repo_addr=$(echo $ecr_repo_uri | cut -d '/' -f1) #e.g. 709843417989.dkr.ecr.eu-central-1.amazonaws.com
container_path=$(dirname $(realpath $0))/container
dockerfile_path=container/hello/Dockerfile

####################################################
# AWS CLI
####################################################
aws ecr get-login-password \
	--region $region | docker login --username AWS --password-stdin $ecr_repo_addr

####################################################
# Docker
####################################################

docker image rm $ecr_repo_name:latest || true
docker build -t $ecr_repo_name:latest -f $dockerfile_path $container_path
docker tag $ecr_repo_name:latest $ecr_repo_uri
docker push $ecr_repo_uri
