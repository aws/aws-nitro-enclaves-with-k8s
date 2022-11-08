#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

####################################################
# LOAD SETTINGS
####################################################
source $(dirname $0)/utils.sh

####################################################
# Misc Specification
####################################################
misc_specification=$(cat<<EOF
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
  name: aws-nitro-enclaves-k8s-daemonset
  namespace: kube-system
  labels:
    name: aws-nitro-enclaves-k8s-dp
    role: agent
spec:
  selector:
    matchLabels:
      name: aws-nitro-enclaves-k8s-dp
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels: 
        name: aws-nitro-enclaves-k8s-dp
      annotations:
        node.kubernetes.io/bootstrap-checkpoint: "true"
    spec: 
      nodeSelector:
        aws-nitro-enclaves-k8s-dp: enabled
      priorityClassName: "system-node-critical"
      hostname: aws-nitro-enclaves-k8s-dp
      containers:
      - name: aws-nitro-enclaves-k8s-dp
        image: 709843417989.dkr.ecr.eu-central-1.amazonaws.com/plugin_devel:latest
        imagePullPolicy: IfNotPresent
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
# Get node name
####################################################

NODE_NAME=$(kubectl get nodes -o json | jq -r '.items[].metadata.name')

[ -z "${NODE_NAME}" ] && { 
	echo "Error while getting node name!"
	exit 1
}

####################################################
# Create a yaml file
####################################################

reset_ifs
printf '%s\n' $misc_specification > aws-nitro-enclaves-k8s-ds.yaml
restore_ifs

####################################################
# Apply the specification file and label the worker node 
####################################################

kubectl label node ${NODE_NAME} aws-nitro-enclaves-k8s-dp-
echo "Enabling Nitro Enclaves K8s device plugin..."
kubectl apply -f aws-nitro-enclaves-k8s-ds.yaml
echo "Labelling node ${NODE_NAME}..."
kubectl label node ${NODE_NAME} aws-nitro-enclaves-k8s-dp=enabled
echo "Done."
