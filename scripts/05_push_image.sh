#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

###################################################
# Helper functions
####################################################

repository_exists() {
  local repo_name=$1
  local result=$(aws ecr describe-repositories --region $CONFIG_REGION | \
              jq -r --arg rn "$repo_name" '.repositories[]|select(.repositoryName==$rn)| .repositoryName')
  [[ "$result" != "$repo_name" ]] && return $FAILURE
  return $SUCCESS
}

create_ecr_repository() {
  local repo_name=$1
  awscli ecr create-repository \
      --repository-name $repo_name \
      --image-tag-mutability MUTABLE
}

###################################################
# Main
####################################################

main() {
  local project_name=$1
  local repo_name="$project_name-$CONFIG_SETUP_UUID"

  repository_exists $repo_name || {
    say_warn "Creating an ECR repository: $repo_name."

    create_ecr_repository $repo_name || {
      say_err "Cannot create repository with name $repo_name."
      return $FAILURE
    }
  }

  local image="$repo_name:latest"
  local repo_uri=$(get_repository_uri $repo_name)

  docker tag $image $repo_uri || {
    say_err "Canno tag image $image! Please ensure that you built the image!"
    return $FAILURE
  }

  [[ "$repo_uri" != "null" ]] || {
    say_err "Cannot get repository URI for $repo_name!"
    return $FAILURE
  }
 
  local registry_addr=${repo_uri/%"/$repo_name"}
  
  docker_login $registry_addr $CONFIG_REGION || {
    say_error "Cannot log in to ${registry_addr}!"
    return $FAILURE
  }
 
  docker push $repo_uri
}
