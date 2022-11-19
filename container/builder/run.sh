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

parse_required_items() {
  local arch=$(uname -m)
  local ctr=0

  readonly items=(
    .name
    .repository
    .tag
    .eif.name
    .eif.docker.image_name
    .eif.docker.image_tag
    .eif.docker.target
    .eif.docker.$arch.file_name
    .eif.docker.$arch.file_path
    .eif.docker.$arch.build_path
  )

  jq -r --arg arch "$arch" \
    '.name, .repository, .tag,
    .eif.name,
    .eif.docker.image_name,
    .eif.docker.image_tag,
    .eif.docker.target,
    .eif.docker."'"$arch"'".file_name,
    .eif.docker."'"$arch"'".file_path,
    .eif.docker."'"$arch"'".build_path' \
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
        item=$(echo ${item/"."/"_"})
        echo "export MANIFEST_${item^^}=\"$value\"" >> .config
        let "ctr=ctr+1"
      done
}

parse_instance_items() {
  local arch=$(uname -m)
  local ctr=0

  readonly items=(
    .instance.docker.image_name
    .instance.docker.image_tag
    .instance.docker.target
    .instance.docker.$arch.file_name
    .instance.docker.$arch.file_path
    .instance.docker.$arch.build_path
  )

  jq -r --arg arch "$arch" \
   '.instance.docker.image_name,
    .instance.docker.image_tag,
    .instance.docker.target,
    .instance.docker."'"$arch"'".file_name,
    .instance.docker."'"$arch"'".file_path,
    .instance.docker."'"$arch"'".build_path' \
    $BUILDER_INSTANCE_ENCLAVE_MANIFEST | \
    while IFS= read -r value ; \
      do
        local item=${items[$ctr]:1}
        [[ "null" = "$value" ]] && {
          say_err "Missing instance application definition: $item!"
          return $FAILURE
        }
        item=$(echo ${item/".$arch"/""})
        item=$(echo ${item/"."/"_"})
        item=$(echo ${item/"."/"_"})
        echo "export MANIFEST_${item^^}=\"$value\"" >> .config
        let "ctr=ctr+1"
      done
}

parse_manifest_file() {
  truncate -s 0 .config
  parse_required_items || die "Cannot parse manifest file!"
  local out=$(jq -r '.instance' $BUILDER_INSTANCE_ENCLAVE_MANIFEST)
  [[ "$out" != "null" ]] && {
    # Instance application-related fields are optional. However, once an instance
    # JSON object is defined, it must include all items required for build.
    parse_instance_items || "Cannot parse manifest file!"
  }
  return $SUCCESS
}

function all_exported_files_exist() {
  # Get exported files list.
  local exported_files=($(jq -r '[.instance.exports[]]|join(" ")' \
    $BUILDER_INSTANCE_ENCLAVE_MANIFEST 2> /dev/null))

  for exp_file in ${exported_files[@]}
  do
    [[ -f "$BUILDER_INSTANCE_OUTPUT_PATH/$(basename $exp_file)" ]] || return $FAILURE;
  done

  return $SUCCESS
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

  all_exported_files_exist; local exp_files_exist=$?

  [[ $exp_files_exist -eq 0 && -f "$BUILDER_INSTANCE_OUTPUT_PATH/$MANIFEST_EIF_NAME" ]] && {
    say "All enclave application already exist in the $BUILDER_INSTANCE_OUTPUT_PATH folder." \
        "Skipping build..."
    return $SUCCESS
  }

  clone_repository $MANIFEST_REPOSITORY $MANIFEST_NAME $MANIFEST_TAG || {
    die "Error while cloning repository of $MANIFEST_NAME!"
  }

  # Build EIF file if it doesn't exist in the bin folder.
  [[ ! -f "$BUILDER_INSTANCE_OUTPUT_PATH/$MANIFEST_EIF_NAME" ]] && {
    local target=""
    [[ "$MANIFEST_EIF_DOCKER_TARGET" != "" ]] && { target="--target $MANIFEST_EIF_DOCKER_TARGET"; }

    # Build EIF File
    docker build -t $MANIFEST_EIF_DOCKER_IMAGE_NAME:$MANIFEST_EIF_DOCKER_IMAGE_TAG \
      $target \
      -f $MANIFEST_NAME/$MANIFEST_EIF_DOCKER_FILE_PATH/$MANIFEST_EIF_DOCKER_FILE_NAME \
      $MANIFEST_NAME/$MANIFEST_EIF_DOCKER_BUILD_PATH || {
        die "Cannot build docker image $MANIFEST_EIF_DOCKER_IMAGE_NAME!"
      }

    build_eif $MANIFEST_EIF_DOCKER_IMAGE_NAME $MANIFEST_EIF_DOCKER_IMAGE_TAG \
      $MANIFEST_EIF_NAME || die "Cannot build eif file!"
  }

  # Build instance application if available
  [[ $exp_files_exist -ne 0 && ! -z $MANIFEST_INSTANCE_DOCKER_IMAGE_NAME ]]  && {
    target=""
    [[ "$MANIFEST_INSTANCE_DOCKER_TARGET" != "" ]] && { target="--target $MANIFEST_INSTANCE_DOCKER_TARGET"; }

    docker build -t $MANIFEST_INSTANCE_DOCKER_IMAGE_NAME:$MANIFEST_INSTANCE_DOCKER_IMAGE_TAG \
      $target \
      -f $MANIFEST_NAME/$MANIFEST_INSTANCE_DOCKER_FILE_PATH/$MANIFEST_INSTANCE_DOCKER_FILE_NAME \
      $MANIFEST_NAME/$MANIFEST_INSTANCE_DOCKER_BUILD_PATH || {
        die "Cannot build docker image $MANIFEST_INSTANCE_DOCKER_IMAGE_NAME!"
      }
  }

  return $SUCCESS
}

main
