#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# Main
####################################################

main() {
  local pod_name="$1"

  # Get pod information
  kubectl describe pod $pod_name
  say "-----------------------------------------------------"
  # Get logs if the enclave is running in debug mode.
  kubectl logs $pod_name
}
