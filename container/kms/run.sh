#!/bin/bash
#Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

EIF_FNAME=kmstool.eif
EIF_PATH=/home/${EIF_FNAME}
LOG_PATH=/tmp/

ENCLAVE_CPU_COUNT=2
ENCLAVE_MEMORY_SIZE=564

mkdir -p /run/nitro_enclaves
nitro-enclaves-allocator

ACCOUNT_ID=$(aws sts get-caller-identity | jq -r .Account)
echo $ACCOUNT_ID
sed -i "s/ACCOUNT_ID/${ACCOUNT_ID}/g" /home/test-enclave-policy.json

KMS_KEY_ARN=$(aws kms create-key --description "Nitro Enclaves Test Key" --policy file:///home/test-enclave-policy.json --query KeyMetadata.Arn --output text)
echo $KMS_KEY_ARN

MESSAGE="Hello, KMS\!"
CIPHERTEXT=$(aws kms encrypt --key-id "$KMS_KEY_ARN" --plaintext "$MESSAGE" --query CiphertextBlob --output text --region eu-central-1)
echo $CIPHERTEXT

nitro-cli describe-enclaves 2>/dev/null
nitro-cli run-enclave --cpu-count ${ENCLAVE_CPU_COUNT} --memory ${ENCLAVE_MEMORY_SIZE} --eif-path ${EIF_PATH} --debug-mode

ENCLAVE_ID=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveID")
echo "Enclave ID is ${ENCLAVE_ID}"
ENCLAVE_CID=$(nitro-cli describe-enclaves | jq -r .[0].EnclaveCID)
echo "Enclave CID is ${ENCLAVE_CID}"

CMK_REGION=eu-central-1
vsock-proxy 8000 kms.$CMK_REGION.amazonaws.com 443 &

KMS_OUTPUT=$(./kmstool_instance --cid "$ENCLAVE_CID" --region "$CMK_REGION" "$CIPHERTEXT")
echo $KMS_OUTPUT

nitro-cli console --enclave-id ${ENCLAVE_ID} 
nitro-cli terminate-enclave --enclave-id ${ENCLAVE_ID}

