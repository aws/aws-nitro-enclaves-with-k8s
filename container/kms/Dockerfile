# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

FROM amazonlinux

RUN amazon-linux-extras install aws-nitro-enclaves-cli && \
    yum install aws-nitro-enclaves-cli-devel -y && \
    yum install jq awscli -y

COPY bin/kmstool.eif               /home/kmstool.eif
COPY bin/kmstool_instance          /kmstool_instance
COPY bin/libnsm.so                 /usr/lib64/libnsm.so
COPY kms/test-enclave-policy.json  /home/test-enclave-policy.json
COPY kms/run.sh                    /home/run.sh

CMD ["/home/run.sh"]
