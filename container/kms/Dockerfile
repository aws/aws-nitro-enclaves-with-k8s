# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

######## full image ########

FROM amazonlinux as full_image

# Install packages
#
RUN amazon-linux-extras install aws-nitro-enclaves-cli && \
    yum install aws-nitro-enclaves-cli-devel jq util-linux \
        unzip curl which file -y

# Install awscli v2
#
RUN \
    cd tmp && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-$(arch).zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

WORKDIR /ne-deps

# Copy only the required binaries to /ne-deps folder.
#
RUN BINS="\
    /usr/local/bin/aws \
    /usr/bin/nitro-cli \
    /usr/bin/vsock-proxy \
    /usr/bin/file \
    /usr/bin/jq \
    /usr/bin/lscpu \
    /usr/bin/which \
    " && \
    for bin in $BINS; do \
        { echo "$bin"; ldd "$bin" | grep -Eo "/.*lib.*/[^ ]+"; } | \
            while read path; do \
                mkdir -p ".$(dirname $path)"; \
                cp -fL "$path" ".$path"; \
            done \
    done

# Prepare other required files and folders for the final image.
#
RUN \
    mkdir -p /ne-deps/etc/nitro_enclaves && \
    mkdir -p /ne-deps/run/nitro_enclaves && \
    mkdir -p /ne-deps/var/log/nitro_enclaves && \
    cp -rf /usr/local/ /ne-deps/usr/ && \
    cp -rf /usr/share/nitro_enclaves/ /ne-deps/usr/share/ && \
    cp -f /etc/nitro_enclaves/vsock-proxy.yaml /ne-deps/etc/nitro_enclaves

######## kms image ########

FROM amazonlinux:2 as image

# Set Environment Variables
#
ARG config_region
ENV config_region=${config_region}
# Set this variable to yes to see more verbose log messages.
ENV config_verbose="no"

# Copying dependencies of the enclave apps from the 'full_image'
# to shrink the final image size.
#
COPY --from=full_image /ne-deps /

COPY bin/kmstool_instance          /usr/bin/kmstool_instance
COPY bin/libnsm.so                 /usr/lib64/libnsm.so

WORKDIR /home

COPY bin/kmstool.eif               kmstool.eif
COPY kms/test-enclave-policy.json  test-enclave-policy.json
COPY kms/run.sh                    run.sh

RUN \
    bash -c "echo CMK_REGION=${config_region} >> .config" && \
    bash -c "echo CONFIG_VERBOSE=${config_verbose} >> .config"

CMD ["/home/run.sh"]
