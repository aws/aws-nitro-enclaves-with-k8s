#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# Main
####################################################

main() {
  local tool_image_name=$1
  local deployment_file="$WORKING_DIR/${tool_image_name}_deployment.yaml"

  kubectl delete -f $deployment_file || {
    say_err "Error while stopping application $tool_image_name!"
  }

  trigger_event $tool_image_name on_stop
}
