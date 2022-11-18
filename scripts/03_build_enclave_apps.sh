#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# Constants
####################################################

readonly BUILDER_CONTAINER_DIR=$WORKING_DIR/container
readonly BUILDER_ARTIFACTS_DIR=$BUILDER_CONTAINER_DIR/bin
readonly BUILDER_DOCKERFILE=$BUILDER_CONTAINER_DIR/builder/Dockerfile.builder
readonly BUILDER_IMAGE=ne-example-builder:latest

####################################################
# Helper functions
####################################################

# Builds .eif file and other binary files defined by the
# example's Dockerfile. If the build succeeds, the EIF
# file is automatically exported to the artifacts folder.
build_enclave_apps() {
  local project_name=$1

  docker run \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $BUILDER_ARTIFACTS_DIR:/output \
    -v $BUILDER_CONTAINER_DIR/$project_name:/source \
    -it $BUILDER_IMAGE
}

# Exports additional files defined in the enclave manifest file
# to the artifacts folder.
export_files() {
  local enclave_manifest="$BUILDER_CONTAINER_DIR/$project_name/enclave_manifest.json"
  # Get the name:tag information of the image.
  local apps_image=$(jq -r '.docker | "\(.image_name):\(.image_tag)"' $enclave_manifest)
  # Get exported files list.
  local exported_files=($(jq -r '[.exports[]]|join(" ")' $enclave_manifest 2> /dev/null))

  for item in ${exported_files[@]}
  do
    say "Exporting $item..."
    copy_from_docker_image $apps_image $item $BUILDER_ARTIFACTS_DIR
  done
}

####################################################
# Main
####################################################
main() {
  # Build image builder if it doesn't exist already.
  # This container image has all dependencies installed
  # that we need to build enclave images.
  docker build -t ${BUILDER_IMAGE} -f ${BUILDER_DOCKERFILE} ${BUILDER_CONTAINER_DIR}
  mkdir -p ${BUILDER_ARTIFACTS_DIR}

  local project_name=$1

  [[ ! -d $BUILDER_CONTAINER_DIR/$project_name ]] && {
    say_err "Cannot find $project_name under $BUILDER_CONTAINER_DIR directory."
    return $FAILURE
  }

  # Build enclave apps
  build_enclave_apps $project_name || {
    say_err "Enclave apps build failed with error. (Code: $?)"
    return $FAILURE
  }

  # .eif file has already been built and exported to $BUILDER_ARTIFACTS_DIR
  # directory. Let's check if we have any other exports defined in the manifest file.
  export_files $project_name || {
    say_err "Enclave apps build failed at export stage with error. (Code: $?)"
    return $FAILURE
  }
}
