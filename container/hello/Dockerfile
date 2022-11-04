# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0


FROM amazonlinux

RUN amazon-linux-extras install aws-nitro-enclaves-cli && \
    yum install aws-nitro-enclaves-cli-devel -y

COPY bin/hello.eif /home
COPY hello/run.sh  /home

CMD ["/home/run.sh"]
