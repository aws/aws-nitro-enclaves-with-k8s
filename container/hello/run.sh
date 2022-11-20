#!/bin/bash -e
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

readonly EIF_PATH="/home/hello.eif"
readonly ENCLAVE_CPU_COUNT=2
readonly ENCLAVE_MEMORY_SIZE=128

main() {
    nitro-cli run-enclave --cpu-count $ENCLAVE_CPU_COUNT --memory $ENCLAVE_MEMORY_SIZE \
        --eif-path $EIF_PATH --debug-mode

    local enclave_id=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveID")
    echo "-------------------------------"
    echo "Enclave ID is $enclave_id"
    echo "-------------------------------"

    nitro-cli console --enclave-id $enclave_id # blocking call.
}

main