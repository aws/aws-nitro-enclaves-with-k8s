# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

FROM amazonlinux

RUN yum upgrade -y && \
    amazon-linux-extras install aws-nitro-enclaves-cli && \
    yum install wget git aws-nitro-enclaves-cli-devel -y

WORKDIR /home

COPY hello hello
COPY kms kms
COPY builder/run.sh run.sh

CMD ["/home/run.sh"]
