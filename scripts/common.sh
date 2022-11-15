#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

readonly DEBUG=false

readonly WORKING_DIR=$(cd $(dirname $(realpath ${BASH_SOURCE[0]}))/../ && pwd)
readonly SCRIPTS_DIR=$WORKING_DIR/scripts
readonly CONTAINER_DIR=$WORKING_DIR/container

readonly FILE_SETUP_ID=".setup.ne.k8s.ctl"
readonly FILE_CONFIGURATION=".config.ne.k8s.ctl"
readonly FILE_CLUSTER_CONFIG="cluster_config.yaml"
readonly FILE_K8S_DEVICE_PLUGIN_MANIFEST="aws-nitro-enclaves-k8s-ds.yaml"

readonly FILE_HOOKS="hooks.sh"

readonly DIRECTORY_DEMO_BINARIES="$WORKING_DIR/container/bin"
