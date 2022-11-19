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
  local enclave_manifest=$1
  # Get the name:tag information of the image.
  local apps_image=$(jq -r '.docker | "\(.image_name):\(.image_tag)"' $enclave_manifest)
  # Get exported files list.
  local exported_files=($(jq -r '[.exports[]]|join(" ")' $enclave_manifest 2> /dev/null))

  for exp_file in ${exported_files[@]}
  do
    say "Exporting $exp_file..."
    [ -f "$BUILDER_ARTIFACTS_DIR/$(basename $exp_file)" ] && {
      say_warn "$(basename $exp_file) already exists in the bin/ directory."
      continue;
    }
    copy_from_docker_image $apps_image $exp_file $BUILDER_ARTIFACTS_DIR
  done
}

####################################################
# Main
####################################################
main() {
  local project_name=$1

  # Build image builder if it doesn't exist already.
  # This container image has all dependencies installed
  # that we need to build enclave images.
  docker build -t $BUILDER_IMAGE -f $BUILDER_DOCKERFILE $BUILDER_CONTAINER_DIR
  mkdir -p $BUILDER_ARTIFACTS_DIR

  [[ ! -d $BUILDER_CONTAINER_DIR/$project_name ]] && {
    say_err "Cannot find $project_name under $BUILDER_CONTAINER_DIR directory."
    return $FAILURE
  }

  local enclave_manifest="$BUILDER_CONTAINER_DIR/$project_name/enclave_manifest.json"
  local eif_file=($(jq -r '.eif_name' $enclave_manifest 2> /dev/null))
  local skip_eif_build=false

  [ -f "$BUILDER_ARTIFACTS_DIR/$eif_file" ] && {
    say_warn "$eif_file already exists. Existing EIF file will be reused."
    skip_eif_build=true;
  }

  # Build enclave apps
  [[ "$skip_eif_build" != true ]] && {
    build_enclave_apps $project_name || {
      say_err "Enclave apps build failed with error. (Code: $?)"
      return $FAILURE
    }
  }

  # .eif file has already been built and exported to $BUILDER_ARTIFACTS_DIR
  # directory. Let's check if we have any other exports defined in the manifest file.
  export_files $enclave_manifest || {
    say_err "Enclave apps build failed at export stage with error. (Code: $?)"
    return $FAILURE
  }
}
