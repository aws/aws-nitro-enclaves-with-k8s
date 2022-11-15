#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

on_run() {
  return $SUCCESS
}

on_podspec_requested() {
  local container_name=$1
  local repo_uri=$2
  local podspec_file=$3

readonly pod_spec=$(cat<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $container_name
spec:
  containers:
    - name: $container_name
      image: $repo_uri:latest
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
  reset_ifs
  printf '%s\n' $pod_spec > $podspec_file || return $FAILURE
  restore_ifs

  return $SUCCESS
}

on_stop() {
  return $SUCCESS
}