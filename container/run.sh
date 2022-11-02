#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

EIF_FNAME=hello.eif
EIF_PATH=/home/${EIF_FNAME}
LOG_PATH=/tmp/

ENCLAVE_CPU_COUNT=2
ENCLAVE_MEMORY_SIZE=512

mkdir -p /run/nitro_enclaves

nitro-cli describe-enclaves 2>/dev/null
nitro-cli run-enclave --cpu-count ${ENCLAVE_CPU_COUNT} --memory ${ENCLAVE_MEMORY_SIZE} --eif-path ${EIF_PATH} --debug-mode

ENCLAVE_ID=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveID")
echo "Enclave ID is ${ENCLAVE_ID}"

nitro-cli console --enclave-id ${ENCLAVE_ID} 
nitro-cli terminate-enclave --enclave-id ${ENCLAVE_ID}
