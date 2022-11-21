#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# Helper Functions
####################################################

_create_deployment_file() {
  local filepath=$1
  local container_name=$2
  local repository_uri=$3

readonly file_content=$(cat<<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: $container_name
        image: $repository_uri:latest
        command: ["/home/run.sh"]
        imagePullPolicy: Always
        resources:
          limits:
            aws.ec2.nitro/nitro_enclaves: "1"
            hugepages-2Mi: 512Mi
            memory: 2Gi
            cpu: 250m
          requests:
            aws.ec2.nitro/nitro_enclaves: "1"
            hugepages-2Mi: 512Mi
        volumeMounts:
        - mountPath: /dev/hugepages
          name: hugepage
          readOnly: false
      tolerations:
      - effect: NoSchedule
        operator: Exists
      - effect: NoExecute
        operator: Exists
      volumes:
        - name: hugepage
          emptyDir:
            medium: HugePages
EOF
)
  # Create deployment yaml file
  #
  reset_ifs
  printf '%s\n' $file_content > $filepath || return $FAILURE
  restore_ifs

  return $SUCCESS
}

####################################################
# Events
####################################################

on_run() {
  return $SUCCESS
}

on_file_requested() {
  local filename=$1
  local target_dir=$2
  local retval=$SUCCESS

  case $filename in
  "hello_deployment.yaml")
    local fullpath=$target_dir/$filename
    local container_name=$3;
    local repository_uri=$4;
    _create_deployment_file "$fullpath" "$container_name" "$repository_uri"; retval=$?;
    ;;
  *)
    say_err "${FUNCNAME[0]}: Requested file $1 is unknown."
    retval=$FAILURE
    ;;
  esac

  return $retval
}

on_stop() {
  return $SUCCESS
}