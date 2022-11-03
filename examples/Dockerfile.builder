# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

FROM amazonlinux

RUN yum upgrade -y && \
    amazon-linux-extras install aws-nitro-enclaves-cli && \
    yum install aws-nitro-enclaves-cli-devel -y

WORKDIR /home

COPY hello-nitro-enclaves hello-nitro-enclaves
COPY kms kms
COPY run.sh run.sh

CMD ["/home/run.sh"]
