#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source "$(dirname $(realpath ${BASH_SOURCE[0]}))/common.sh"
source "$WORKING_DIR/scripts/utils.sh"

####################################################
# Constants
####################################################

readonly MY_NAME="fetch-prebuilt"

readonly DEMO_BIN_REGISTRY=709843417989.dkr.ecr.eu-west-1.amazonaws.com
readonly DEMO_BIN_REPOSITORY_NAME=ne-kms-demo-binaries
readonly DEMO_BIN_REPOSITORY_TAG=latest
readonly DEMO_BIN_REGION="eu-west-1"
readonly DEMO_BIN_IMAGE=$DEMO_BIN_REGISTRY/$DEMO_BIN_REPOSITORY_NAME:$DEMO_BIN_REPOSITORY_TAG

readonly DEMO_BINARIES=(hello.eif kmstool_instance kmstool.eif libnsm.so)

####################################################
# Helper functions
####################################################

check_existing_binaries() {
  for binary in ${DEMO_BINARIES[@]}
  do
    [ -f $DIRECTORY_DEMO_BINARIES/$binary ] && {
      say_warn "container/bin directory already contains some files." \
          "This operation will overwrite existing files."
      read -p "Are you sure want to continue? (y/n)" yn
      case $yn in
        [Yy]* ) break;;
        * ) die "Fetch operation has been cancelled!";;
      esac
    }
  done
}

# Extracts all demo binaries inside from container to the
# containers/bin directory.
extract_demo_binaries() {
  for binary in ${DEMO_BINARIES[@]}
  do
    say "Extracting $binary..."
    copy_from_docker_image $DEMO_BIN_IMAGE $binary $DIRECTORY_DEMO_BINARIES \
      || return $FAILURE
  done
}

####################################################
# Main
####################################################

main() {
  check_existing_binaries

  #TODO: Remove after public repository becomes available.
  docker_login $DEMO_BIN_REGISTRY $DEMO_BIN_REGION || {
    say_warn "Cannot log in to ${DEMO_BIN_REGISTRY}!"
    return $FAILURE
  }

  docker pull $DEMO_BIN_IMAGE || {
    say_err "Cannot fetch ${DEMO_BIN_REPOSITORY_NAME} from registry ${DEMO_BIN_REGISTRY}!"
    return $FAILURE
  }

  extract_demo_binaries || {
    say_err "Demo binaries cannot be extracted! Please make sure you have write access for the working directory."
    return $FAILURE
  }
}

main