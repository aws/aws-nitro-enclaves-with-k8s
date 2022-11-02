# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

FROM alpine:latest

RUN apk add --no-cache jq bash util-linux file

COPY hello.eif /home/
COPY run.sh /home
COPY enclave-tools/nitro-cli                /usr/bin/nitro-cli
COPY enclave-tools/nitro-enclaves-allocator /usr/bin/nitro-enclaves-allocator
COPY enclave-tools/allocator.yaml           /etc/nitro_enclaves/allocator.yaml

RUN mkdir -p /usr/share/nitro_enclaves

COPY enclave-tools/blobs/bzImage   /usr/share/nitro_enclaves/blobs/
COPY enclave-tools/blobs/init      /usr/share/nitro_enclaves/blobs/
COPY enclave-tools/blobs/linuxkit  /usr/share/nitro_enclaves/blobs/
COPY enclave-tools/blobs/nsm.ko    /usr/share/nitro_enclaves/blobs/

CMD ["/home/run.sh"]
