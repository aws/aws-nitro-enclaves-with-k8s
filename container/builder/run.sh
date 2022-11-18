#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

readonly SUCCESS=0
readonly FAILURE=255

readonly BUILDER_INSTANCE_OUTPUT_PATH=/output
readonly BUILDER_INSTANCE_SOURCE_PATH=/source
readonly BUILDER_INSTANCE_ENCLAVE_MANIFEST="$BUILDER_INSTANCE_SOURCE_PATH/enclave_manifest.json"

die() {
  local code=1
  [[ "$1" = "-c" ]] && {
    code="$2"
    shift 2
  }
  say_err "$@"
  exit $code
}

say_err() {
  [ -t 2 ] && [ -n "$TERM" ] \
    && echo "$(tput setaf 1)[BUILDER] $*$(tput sgr0)" 1>&2 \
    || echo "[BUILDER] $*" 1>&2
}

say() {
  [ -t 1 ] && [ -n "$TERM" ] \
    && echo "$(tput setaf 2)[BUILDER]$(tput sgr0) $*" \
    || echo "[BUILDER] $*"
}

build_eif() {
  local image_name=$1
  local tag=$2
  local eif_name=$3

  nitro-cli build-enclave --docker-uri $image_name:$tag --output-file /output/$eif_name
}

clone_repository() {
  local repo_addr=$1
  local directory=$2
  local tag=$3

  git clone --depth 1 $repo_addr -b $tag $directory
}

parse_manifest_file() {
  local arch=$(uname -m)
  local ctr=0

  # TODO: Generate jq's query from here.
  readonly items=(
    .docker.$arch.file_name
    .docker.$arch.file_path
    .docker.$arch.build_path
    .docker.image_name
    .docker.image_tag
    .docker.target
    .name
    .repository
    .tag
    .eif_name
  )

  truncate -s 0 .config

  jq -r --arg arch "$arch" \
    '.docker."'"$arch"'".file_name,
    .docker."'"$arch"'".file_path,
    .docker."'"$arch"'".build_path,
    .docker.image_name,
    .docker.image_tag,
    .docker.target,
    .name, .repository, .tag, .eif_name' \
    $BUILDER_INSTANCE_ENCLAVE_MANIFEST | \
    while IFS= read -r value ; \
      do
        local item=${items[$ctr]:1}
        [[ "null" = "$value" ]] && {
          say_err "Manifest file must include item: $item!"
          return $FAILURE
        }
        item=$(echo ${item/".$arch"/""})
        item=$(echo ${item/"."/"_"})
        echo "export MANIFEST_${item^^}=\"$value\"" >> .config
        let "ctr=ctr+1"
      done
}

main() {
  [[ -f $BUILDER_INSTANCE_ENCLAVE_MANIFEST ]] || {
    die "No enclave manifest file found!" \
    "Please make sure enclave_manifest.json" \
    "exists in the project directory."
  }

  parse_manifest_file || {
    die "Invalid enclave manifest file! Aborting..."
  }

  source .config
  say "---- Using config: ----"
  cat .config
  say "-----------------------"

  clone_repository $MANIFEST_REPOSITORY $MANIFEST_NAME $MANIFEST_TAG || {
    die "Error while cloning repository of $MANIFEST_NAME!"
  }

  local target=""
  [[ "$MANIFEST_DOCKER_TARGET" != "" ]] && { target="--target $MANIFEST_DOCKER_TARGET"; }

  docker build -t $MANIFEST_DOCKER_IMAGE_NAME:$MANIFEST_DOCKER_IMAGE_TAG \
    $target \
    -f $MANIFEST_NAME/$MANIFEST_DOCKER_FILE_PATH/$MANIFEST_DOCKER_FILE_NAME \
    $MANIFEST_NAME/$MANIFEST_DOCKER_BUILD_PATH || {
      die "Cannot build docker image $MANIFEST_DOCKER_IMAGE_NAME!"
    }

  build_eif $MANIFEST_DOCKER_IMAGE_NAME $MANIFEST_DOCKER_IMAGE_TAG \
    $MANIFEST_EIF_NAME || die "Cannot build eif file!"
}

main
