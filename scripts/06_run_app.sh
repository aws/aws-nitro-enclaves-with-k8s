#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# Main
####################################################

main() {
  local tool_image_name=$1
  local image_name="$tool_image_name-$CONFIG_SETUP_UUID"
  local repository_uri=$(get_repository_uri $image_name)

  [[ "$repository_uri" == "null" || "$repository_uri" == "" ]] && {
    say_err "Cannot get repository URI for $repository_name!"
    return $FAILURE
  }

  local deployment_file="${tool_image_name}_deployment.yaml"

  # Prepare necessary resources before running the app.
  trigger_event $tool_image_name on_run
  # Render a deployment file.
  trigger_event $tool_image_name \
                on_file_requested \
                "$deployment_file" \
                "$WORKING_DIR" \
                "$image_name" \
                "$repository_uri"

  say "Generated deployment file: $deployment_file."
  local prepare_only=$2
  [[ "$prepare_only" != false ]] && { return $SUCCESS; }

  kubectl apply -f "$WORKING_DIR/$deployment_file" || {
    say_err "Error while applying deployment file: $deployment_file"
    return $FAILURE
  }
}

