#!/bin/bash -e
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

function build_eif {
	local image_name=$1
	local tag=$2
	local eif_name=$3

	nitro-cli build-enclave --docker-uri $image_name:$tag --output-file /output/$eif_name
}

declare -A hello=( 
	[image_name]="ne-build-example-hello" 
	[tag]="1.0"
	[path]="hello-nitro-enclaves"
	[eif]="hello.eif"
	[target]="default"
)

declare -A kms=( 
	[image_name]="ne-build-example-kms" 
	[tag]="1.0"
	[path]="kms"
	[eif]="kmstool.eif"
	[target]="kmstool-enclave"
)

declare -A kmstool_instance=( 
	[image_name]="ne-build-example-kmstool-instance" 
	[tag]="1.0"
	[path]="kms"
	[target]="kmstool-instance"
)

# Build EIF for hello demo
docker build --target ${hello[target]} -t ${hello[image_name]}:${hello[tag]} ${hello[path]}
build_eif ${hello[image_name]} ${hello[tag]} ${hello[eif]}

# Build EIF for KMS demo
docker build --target ${kms[target]} -t ${kms[image_name]}:${kms[tag]} ${kms[path]}
build_eif ${kms[image_name]} ${kms[tag]} ${kms[eif]}

# Build KMS instance tool
docker build --target ${kmstool_instance[target]} -t ${kmstool_instance[image_name]}:${kmstool_instance[tag]} ${kmstool_instance[path]}