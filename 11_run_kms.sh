#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

####################################################
# LOAD SETTINGS
####################################################
source $(dirname $0)/utils.sh
ecr_repo_uri=$(cat last_kms_repository.uri)

####################################################
# Pod Specification
####################################################

pod_specification=$(cat<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $ecr_kms_repo_name
spec:
  serviceAccountName: ne-service-account
  containers:
    - name: $ecr_kms_repo_name
      image: $ecr_repo_uri:latest
      command: ["/home/run.sh"]
      imagePullPolicy: Always
      resources:
        limits:
          aws.ec2.nitro/nitro_enclaves: "1"
          hugepages-2Mi: 564Mi
          memory: 2Gi
          cpu: 250m
        requests:
          aws.ec2.nitro/nitro_enclaves: "1"
          hugepages-2Mi: 564Mi
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

####################################################
# Create PodSpec yaml file
####################################################

reset_ifs
printf '%s\n' $pod_specification > ne_pod.yaml
restore_ifs

####################################################
# Run the pod
####################################################
kubectl delete -f ne_pod.yaml
kubectl apply -f ne_pod.yaml 
