#!/bin/bash -e
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

ARTIFACTS_DIR=$(dirname $(realpath $0))/bin

BUILDER=ne-example-builder:latest
KMSTOOL_IMAGE=ne-build-example-kmstool-instance:1.0

DOCKERFILE=Dockerfile.builder

#docker image rm ${BUILDER}
docker build -t ${BUILDER} -f ${DOCKERFILE} .

mkdir -p ${ARTIFACTS_DIR}

# Build .eif files and copy them to output directory.
docker run \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v ${ARTIFACTS_DIR}:/output \
	-it ${BUILDER}

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
