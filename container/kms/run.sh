#!/bin/bash -e
#Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

readonly MY_NAME="kms-example"

readonly EIF_PATH="/home/kmstool.eif"
readonly ENCLAVE_CPU_COUNT=2
readonly ENCLAVE_MEMORY_SIZE=576

CIPHERTEXT=""

log() {
    echo -e "[$MY_NAME] $*" 1>&2
}

init() {
    # Load configuration
    # - CMK_REGION
    # - CONFIG_VERBOSE
    source "/home/.config"

    [[ -z "$CMK_REGION" ]] && {
        log "[ERROR]: AWS region cannot be empty!"
        exit 1
    }

    local account_id=$(aws sts get-caller-identity | jq -r .Account)
    sed -i "s/ACCOUNT_ID/${account_id}/g" /home/test-enclave-policy.json

    log "Creating a KMS key..."
    local kms_key_arn=$(aws kms create-key --description "Nitro Enclaves Test Key" --policy file:///home/test-enclave-policy.json --query KeyMetadata.Arn --output text)
    local message="Hello, KMS\!"

    log "Encrypting message..."
    CIPHERTEXT=$(aws kms encrypt --key-id "$kms_key_arn" --plaintext "$message" --query CiphertextBlob --output text --region "$CMK_REGION")

    log "******************************"
    log "KMS Key ARN: $kms_key_arn"
    log "Account ID: $account_id"
    log "Unencrypted message: $message"
    log "Ciphertext: $CIPHERTEXT"
    log "******************************"

    nitro-cli run-enclave --cpu-count $ENCLAVE_CPU_COUNT --memory $ENCLAVE_MEMORY_SIZE \
        --eif-path $EIF_PATH --debug-mode 2>&1 > /dev/null

    vsock-proxy 8000 kms.$CMK_REGION.amazonaws.com 443 &
}

uninit() {
    local enclave_id=$1
    nitro-cli terminate-enclave --enclave-id $enclave_id 2>&1 > /dev/null
}

main() {
    init

    local desc=$(nitro-cli describe-enclaves)
    local enclave_id=$(echo $desc | jq -r .[0].EnclaveID)
    local enclave_cid=$(echo $desc | jq -r .[0].EnclaveCID)
    local kms_command="kmstool_instance --cid $enclave_cid --region $CMK_REGION $CIPHERTEXT"
    [[ "$CONFIG_VERBOSE" != "yes" ]] && {
        kms_command+=" 2>&1 | grep \"Object = { \\\"Status\\\"\""
    }

    log "Requesting from the enclave to decrypt message..."

    local kms_output=$(eval $kms_command)
    log "------------------------"
    log "> Got response from the enclave!"
    log $kms_output
    log "------------------------"
    uninit $enclave_id

    sleep infinity
}

main