#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Generic error codes
#
readonly SUCCESS=0
readonly FAILURE=255

####################################################
# Utility functions
####################################################

_IFS=${_IFS-${IFS}}

function reset_ifs {
  IFS=
}

function restore_ifs {
  IFS=$_IFS
}

# ######################################################

# Send an error-decorated text message to stderr
#
say_err() {
  [ -t 2 ] && [ -n "$TERM" ] \
    && echo "$(tput setaf 1)[$MY_NAME] $*$(tput sgr0)" 1>&2 \
    || echo "[$MY_NAME] $*" 1>&2
}

# Send a warning-decorated text message to stderr
#
say_warn() {
  [ -t 2 ] && [ -n "$TERM" ] \
    && echo "$(tput setaf 3)[$MY_NAME] $*$(tput sgr0)" 1>&2 \
    || echo "[$MY_NAME] $*" 1>&2
}

# Send a decorated message to stdout, followed by a new line
#
say() {
  [ -t 1 ] && [ -n "$TERM" ] \
    && echo "$(tput setaf 2)[$MY_NAME]$(tput sgr0) $*" \
    || echo "[$MY_NAME] $*"
}

# Send a debug message to stdout, followed by a new line
#
debug() {
  [ "$DEBUG" == true ] && {
    printf "[DEBUG]"
    say $*
  }
}

# Exit with an error message and (optional) code
# Usage: die [-c <error code>] <error message>
#
die() {
  local code=1
  [[ "$1" = "-c" ]] && {
    code="$2"
    shift 2
  }
  say_err "$@"
  exit $code
}

# Exit with an error message if the last exit code is not 0
#
ok_or_die() {
  local code=$?
  [[ -f log.err ]] && cat log.err 1>&2 && rm -rf log.err
  [[ $code -eq 0 ]] || die -c $code "$@"
}

# ######################################################

function awscli {
  debug "aws "$@" -region $CONFIG_REGION"
  aws "$@" --region $CONFIG_REGION
}

get_launch_template_id() {
  local lt_name=$1
  local out=$(aws ec2 describe-launch-templates --region $CONFIG_REGION)
  ok_or_die "Cannot get launch template information!"
  echo $out | jq -r --arg lt_name "$lt_name" '.LaunchTemplates[] | select(.LaunchTemplateName == $lt_name).LaunchTemplateId'
}

# ######################################################

# Checks if a cluster exists.
#
cluster_exists() {
  local cluster_name=$1
  out=$(aws eks list-clusters --region $CONFIG_REGION)
  local match=$(echo $out | jq -r --arg cname $cluster_name '.clusters[]|select(. == $cname)')
  [[ "$match" != "$cluster_name" ]] && return 255
  debug "[[ $match != $cluster_name ]]"
  return 0
}

# ######################################################

# Copies a file inside from docker image to a host directory.
#
copy_from_docker_image() {
  local image=$1
  local src_file=$2
  local dst_path=$3

  docker run \
    -v $dst_path:/output:rw \
    --rm --entrypoint \
    cp $image $src_file /output/
}

# Logs in to a private ECR
#
docker_login() {
  local registry_address=$1
  local region=$2
  aws ecr get-login-password --region $region | \
     docker login --username AWS --password-stdin $registry_address
}

# Get URI of the given repository name.
get_repository_uri() {
    local repo_name=$1
    local result=$(aws ecr describe-repositories --region $CONFIG_REGION | \
                jq -r --arg rn "$repo_name" '.repositories[]|select(.repositoryName==$rn)| .repositoryUri')
    echo "$result"
}

# ######################################################

trigger_event() {
  local project_name=$1
  local event_name=$2
  local hooks_file=$CONTAINER_DIR/$project_name/$FILE_HOOKS

  [[ -f $hooks_file ]] && {
    debug "Found hooks file for $1!"
    source $hooks_file
    [[ "$(declare -Ff "$event_name")" ]] && {
      debug "Running $event_name."
      shift 2
      $event_name "$@" || die "$event_name @ $hooks_file have failed!"
    }
  }

  return $SUCCESS
}