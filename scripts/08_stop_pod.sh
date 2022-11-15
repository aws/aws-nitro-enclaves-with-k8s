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
  local podspec_file="$WORKING_DIR/$project_name_podspec.yaml"

  kubectl delete -f $podspec_file || {
    say_err "Error while stopping application $project_name!"
  }

  trigger_event $project_name on_stop
}
