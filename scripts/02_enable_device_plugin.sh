#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

####################################################
# Constants
####################################################

readonly DP_DAEMONSET_NAME=aws-nitro-enclaves-k8s-daemonset
readonly DP_PLUGIN_LABEL=aws-nitro-enclaves-k8s-dp

####################################################
# Misc Specification
####################################################
readonly misc_specification=$(cat<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: nitro-enclaves
  labels:
    name: nitro-enclaves
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: $DP_DAEMONSET_NAME
  namespace: kube-system
  labels:
    name: $DP_PLUGIN_LABEL
    role: agent
spec:
  selector:
    matchLabels:
      name: $DP_PLUGIN_LABEL
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: $DP_PLUGIN_LABEL
      annotations:
        node.kubernetes.io/bootstrap-checkpoint: "true"
    spec:
      nodeSelector:
        $DP_PLUGIN_LABEL: enabled
      priorityClassName: "system-node-critical"
      hostname: $DP_PLUGIN_LABEL
      containers:
      - name: $DP_PLUGIN_LABEL
        image: 709843417989.dkr.ecr.eu-central-1.amazonaws.com/plugin_devel:latest #TODO: Use public ECR address
        imagePullPolicy: Always #TODO: Change to IfNotPresent
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        resources:
          limits:
            cpu: 100m
            memory: 15Mi
          requests:
            cpu: 10m
            memory: 15Mi
        volumeMounts:
          - name: device-plugin
            mountPath: /var/lib/kubelet/device-plugins
          - name: dev-dir
            mountPath: /dev
          - name: sys-dir
            mountPath: /sys
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
        - name: dev-dir
          hostPath:
            path: /dev
        - name: sys-dir
          hostPath:
            path: /sys
      terminationGracePeriodSeconds: 30
EOF
)

####################################################
# Helper functions
####################################################

get_node_name() {
  echo $(kubectl get nodes -o json | jq -r '.items[].metadata.name')
}

device_plugin_running() {
  kubectl get pods -n kube-system --field-selector=status.phase=Running \
  | grep $DP_DAEMONSET_NAME 2>&1 > /dev/null
}

unlabel_node() {
  local node_name=$1
  local label=$2
  kubectl label node $node_name $label-
}

label_node() {
  local node_name=$1
  local label=$2
  local value=$3
  kubectl label node $node_name $2=$3
}

####################################################
# Main
####################################################

main() {
  device_plugin_running -eq 0 && {
    say_warn "Device plugin is already enabled and running."
    return $SUCCESS
  }

  reset_ifs
  printf '%s\n' $misc_specification > $FILE_K8S_DEVICE_PLUGIN_MANIFEST
  restore_ifs

  local node_name=$(get_node_name)
  [ -z "${node_name}" ] && {
    say_err "Cannot get K8s node name. Device plugin installation has failed!"
    say_err "Make sure cluster the cluster installation has completed successfully."
    return $FAILURE
  }

  say "Attempt to unlabel node $node_name..."
  unlabel_node $node_name $DP_PLUGIN_LABEL

  say "Enabling Nitro Enclaves K8s device plugin..."
  kubectl apply -f $FILE_K8S_DEVICE_PLUGIN_MANIFEST || {
    say_err "Error applying manifest. ($FILE_K8S_DEVICE_PLUGIN_MANIFEST)"
    return $FAILURE
  }

  say "Labelling node $node_name..."
  label_node $node_name $DP_PLUGIN_LABEL enabled -eq 0 || {
    say_err "Error while labelling ${node_name}."
    return $FAILURE
  }
}
