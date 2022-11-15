#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# Main
####################################################

main() {
	local project_name=$1
	local repo_name="$project_name-$CONFIG_SETUP_UUID"
  local repo_uri=$(get_repository_uri $repo_name)

  [[ "$repo_uri" != "null" ]] || {
    say_err "Cannot get repository URI for $repo_name!"
    return $FAILURE
  }

  local podspec_file="$WORKING_DIR/$project_name_podspec.yaml"

  # Prepare necessary resources before running the app.
  trigger_event $project_name on_run 
  # Render a podspec file.
  trigger_event $project_name on_podspec_requested \
                  "$project_name" "$repo_uri" \
                  "$podspec_file"


  kubectl apply -f $podspec_file || {
    say_err "Error applying podspec file: $pod_spec_file"
    return $FAILURE
  }
}

