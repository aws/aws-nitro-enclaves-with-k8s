#!/bin/bash -e
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

function build_eif {
	local image_name=$1
	local tag=$2
	local eif_name=$3

	nitro-cli build-enclave --docker-uri $image_name:$tag --output-file /output/$eif_name
}

function fetch_file {
	local http_addr=$1
	local directory=$2

	wget --directory-prefix=$directory $http_addr
}

function clone_repository {
	local repo_addr=$1
	local directory=$2

	git clone --depth 1 $repo_addr $directory
}

# Parameters to build hello.eif enclave image.
declare -A hello=( 
	[dockerfile]="https://raw.githubusercontent.com/aws/aws-nitro-enclaves-cli/main/examples/x86_64/hello/Dockerfile"
	[eif]="hello.eif"
	[image_name]="ne-build-hello-eif" 
	[path]="hello-eif"
	[run_script]="https://raw.githubusercontent.com/aws/aws-nitro-enclaves-cli/main/examples/x86_64/hello/hello.sh"
	[run_script_name]="hello.sh"
	[tag]="1.0"
)

# Parameters to build kmstool.eif enclave image.
declare -A kmse=( 
	[dockerfile]="kms-binaries/containers/Dockerfile.al2"
	[eif]="kmstool.eif"
	[image_name]="ne-build-kms-eif" 
	[path]="kms-binaries"
	[repository]="https://github.com/aws/aws-nitro-enclaves-sdk-c"
	[tag]="1.0"
	[target]="kmstool-enclave"
)

# Parameters to build kmstool_instance application that runs on the instance.
declare -A kmsi=( 
	[dockerfile]="kms-binaries/containers/Dockerfile.al2"
	[image_name]="ne-build-kmstool-instance" 
	[path]="kms-binaries"
	[repository]="https://github.com/aws/aws-nitro-enclaves-sdk-c"
	[tag]="1.0"
	[target]="kmstool-instance"
)

# Build EIF for hello demo
mkdir -p ${hello[path]}
fetch_file ${hello[dockerfile]} ${hello[path]}
fetch_file ${hello[run_script]} ${hello[path]}
chmod +x ${hello[path]}/${hello[run_script_name]}
docker build -t ${hello[image_name]}:${hello[tag]} ${hello[path]}
build_eif ${hello[image_name]} ${hello[tag]} ${hello[eif]}

# aws-nitro-enclaves-sdk-c is needed to build KMS deliverables
clone_repository ${kmse[repository]} ${kmse[path]}

# Build EIF for KMS demo
docker build --target ${kmse[target]} -t ${kmse[image_name]}:${kmse[tag]} ${kmse[path]} -f ${kmse[dockerfile]}
build_eif ${kmse[image_name]} ${kmse[tag]} ${kmse[eif]}

# Build KMS instance tool
docker build --target ${kmsi[target]} -t ${kmsi[image_name]}:${kmsi[tag]} ${kmsi[path]} -f ${kmsi[dockerfile]}
