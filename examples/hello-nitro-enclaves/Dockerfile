# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

FROM busybox as default

ENV HELLO="Hello K8s! This is a message from the enclave!"
COPY run.sh /home/run.sh

CMD ["/home/run.sh"]
