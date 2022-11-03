#!/bin/bash -e
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

CONTAINER_DIR=$(dirname $(realpath $0))/container
ARTIFACTS_DIR=${CONTAINER_DIR}/bin

BUILDER_IMAGE=ne-example-builder:latest
KMSTOOL_IMAGE=ne-build-kmstool-instance:1.0

BUILDER_DOCKERFILE=${CONTAINER_DIR}/builder/Dockerfile.builder

#docker image rm ${BUILDER}
docker build -t ${BUILDER_IMAGE} -f ${BUILDER_DOCKERFILE} ${CONTAINER_DIR}

mkdir -p ${ARTIFACTS_DIR}

# Build .eif files and copy them to output directory.
# This container runs docker inside to build eifs and
# kmstool_instance binary. ${KMSTOOL_IMAGE} is also 
# created in this container.
docker run \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v ${ARTIFACTS_DIR}:/output \
	-it ${BUILDER_IMAGE}

# Copy kmstool_instance from container to the output directory.
docker run \
	-v ${ARTIFACTS_DIR}:/output \
	--rm --entrypoint \
	cp ${KMSTOOL_IMAGE} /kmstool_instance /output/kmstool_instance

# Copy libnsm.so from container to the output directory.
docker run \
	-v ${ARTIFACTS_DIR}:/output \
	--rm --entrypoint \
	cp ${KMSTOOL_IMAGE} /usr/lib64/libnsm.so /output/libnsm.so
