#!/bin/bash

####################################################
# Settings
####################################################

LOAD_SETTINGS=$(cat settings.json)

region=$(echo $LOAD_SETTINGS | jq -r '.region')
ami_id=$(echo $LOAD_SETTINGS | jq -r '.ami_id')
instance_type=$(echo $LOAD_SETTINGS | jq -r '.instance_type')
cluster_name=$(echo $LOAD_SETTINGS | jq -r '.eks_cluster_name')
managed_wg_name=$(echo $LOAD_SETTINGS | jq -r '.eks_managed_wg_name')
k8s_version=$(echo $LOAD_SETTINGS | jq -r '.k8s_version')
ecr_repo_name=$(echo $LOAD_SETTINGS | jq -r '.ecr_repo_name')
ecr_kms_repo_name=$(echo $LOAD_SETTINGS | jq -r '.ecr_kms_repo_name')

####################################################
# Utility functions
####################################################

# Set if _IFS is null
_IFS=${_IFS-${IFS}}
# printf %q "$_IFS"

function reset_ifs {
    IFS=
}

function restore_ifs {
    IFS=$_IFS	
}
