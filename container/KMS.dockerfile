# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

FROM fedora:34

RUN yum makecache --refresh
RUN yum install jq bash util-linux file awscli -y

COPY kmstool.eif                            /home/kmstool.eif
COPY test-enclave-policy.json               /home/test-enclave-policy.json
COPY run_kms.sh                             /home/run.sh
COPY enclave-tools/kmstool_instance         /kmstool_instance
COPY enclave-tools/libnsm.so                /usr/lib64/libnsm.so
COPY enclave-tools/vsock-proxy              /usr/bin/vsock-proxy
COPY enclave-tools/nitro-cli                /usr/bin/nitro-cli
COPY enclave-tools/nitro-enclaves-allocator /usr/bin/nitro-enclaves-allocator
COPY enclave-tools/allocator.yaml           /etc/nitro_enclaves/allocator.yaml
COPY enclave-tools/vsock-proxy.yaml         /etc/nitro_enclaves/vsock-proxy.yaml

RUN mkdir -p /usr/share/nitro_enclaves

COPY enclave-tools/blobs/bzImage   /usr/share/nitro_enclaves/blobs/
COPY enclave-tools/blobs/init      /usr/share/nitro_enclaves/blobs/
COPY enclave-tools/blobs/linuxkit  /usr/share/nitro_enclaves/blobs/
COPY enclave-tools/blobs/nsm.ko    /usr/share/nitro_enclaves/blobs/

CMD ["/home/run.sh"]
