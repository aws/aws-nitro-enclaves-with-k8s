#!/bin/bash -e
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

####################################################
# LOAD SETTINGS
####################################################
source $(dirname $0)/utils.sh

####################################################
# Confirm fetching if bin folder is not empty.
####################################################

BINARIES=(hello.eif kmstool_instance kmstool.eif libnsm.so)
BIN_DIR=$(dirname $(realpath $0))/container/bin

for binary in ${BINARIES[@]}
do
	[ -f $BIN_DIR/$binary ] && {
		printf "container/bin directory already contains some files.\n \
				This operation will overwrite existing files.\n"
		read -p "Are you sure want to continue? (y/n)" yn
		case $yn in
			[Yy]* ) break;;
			* ) exit;; 
		esac
	}
done

####################################################
# Pull ne-kms-demo-binaries repository
####################################################

# TODO: Replace the registry/repository address when the public one
# becomes available.

NE_KMS_DEMO_BINARIES_IMAGE=709843417989.dkr.ecr.eu-west-1.amazonaws.com/ne-kms-demo-binaries
docker pull 709843417989.dkr.ecr.eu-west-1.amazonaws.com/ne-kms-demo-binaries:latest

####################################################
# Extract files to the container/bin folder
####################################################

for binary in ${BINARIES[@]}
do
	docker run \
		-v ${BIN_DIR}:/output \
		--rm --entrypoint \
		cp $NE_KMS_DEMO_BINARIES_IMAGE:latest $binary /output/$binary
done