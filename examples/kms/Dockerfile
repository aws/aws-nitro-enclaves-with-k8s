# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

FROM amazonlinux as builder

RUN yum upgrade -y && \
    amazon-linux-extras enable epel && \
    yum clean -y metadata && yum install -y epel-release && \
    curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal --default-toolchain 1.60 && \  
    yum install -y cmake3 gcc git tar make gcc-c++ go ninja-build

# We keep the build artifacts in the -build directory
WORKDIR /tmp/crt-builder

RUN git clone --depth 1 -b v1.0.2 https://github.com/awslabs/aws-lc.git aws-lc && \
    cmake3 -DCMAKE_PREFIX_PATH=/usr -DCMAKE_INSTALL_PREFIX=/usr -GNinja -S aws-lc -B aws-lc/build . && \
    go env -w GOPROXY=direct && \
    cmake3 --build aws-lc/build --parallel $(nproc) --target install

RUN git clone --depth 1 -b v1.3.20 https://github.com/aws/s2n-tls.git && \
    cmake3 -DCMAKE_PREFIX_PATH=/usr -DCMAKE_INSTALL_PREFIX=/usr -S s2n-tls -B s2n-tls/build && \
    cmake3 --build s2n-tls/build --parallel $(nproc) --target install

RUN git clone --depth 1 -b v0.8.0 https://github.com/awslabs/aws-c-common.git && \
    cmake3 -DCMAKE_PREFIX_PATH=/usr -DCMAKE_INSTALL_PREFIX=/usr -GNinja -S aws-c-common -B aws-c-common/build && \
    cmake3 --build aws-c-common/build --parallel $(nproc) --target install

RUN git clone --depth 1 -b v0.1.2 https://github.com/awslabs/aws-c-sdkutils.git && \
    cmake3 -DCMAKE_PREFIX_PATH=/usr -DCMAKE_INSTALL_PREFIX=/usr -GNinja -S aws-c-sdkutils -B aws-c-sdkutils/build && \
    cmake3 --build aws-c-sdkutils/build --target install

RUN git clone --depth 1 -b v0.5.18 https://github.com/awslabs/aws-c-cal.git && \
    cmake3 -DCMAKE_PREFIX_PATH=/usr -DCMAKE_INSTALL_PREFIX=/usr -GNinja -S aws-c-cal -B aws-c-cal/build && \
    cmake3 --build aws-c-cal/build --parallel $(nproc) --target install

RUN git clone --depth 1 -b v0.11.0 https://github.com/awslabs/aws-c-io.git && \
    cmake3 -DUSE_VSOCK=1 -DCMAKE_PREFIX_PATH=/usr -DCMAKE_INSTALL_PREFIX=/usr -GNinja -S aws-c-io -B aws-c-io/build && \
    cmake3 --build aws-c-io/build --parallel $(nproc) --target install

RUN git clone --depth 1 -b v0.2.14 http://github.com/awslabs/aws-c-compression.git && \
    cmake3 -DCMAKE_PREFIX_PATH=/usr -DCMAKE_INSTALL_PREFIX=/usr -GNinja -S aws-c-compression -B aws-c-compression/build && \
    cmake3 --build aws-c-compression/build --parallel $(nproc) --target install

RUN git clone --depth 1 -b v0.6.19 https://github.com/awslabs/aws-c-http.git && \
    cmake3 -DCMAKE_PREFIX_PATH=/usr -DCMAKE_INSTALL_PREFIX=/usr -GNinja -S aws-c-http -B aws-c-http/build && \
    cmake3 --build aws-c-http/build --parallel $(nproc) --target install

RUN git clone --depth 1 -b v0.6.15 https://github.com/awslabs/aws-c-auth.git && \
    cmake3 -DCMAKE_PREFIX_PATH=/usr -DCMAKE_INSTALL_PREFIX=/usr -GNinja -S aws-c-auth -B aws-c-auth/build && \
    cmake3 --build aws-c-auth/build --parallel $(nproc) --target install

RUN git clone --depth 1 -b json-c-0.16-20220414 https://github.com/json-c/json-c.git && \
    cmake3 -DCMAKE_PREFIX_PATH=/usr -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF -GNinja -S json-c -B json-c/build && \
    cmake3 --build json-c/build --parallel $(nproc) --target install

RUN git clone --depth 1 -b v0.2.1 https://github.com/aws/aws-nitro-enclaves-nsm-api.git && \
    source $HOME/.cargo/env && cd aws-nitro-enclaves-nsm-api && cargo build --release -p nsm-lib && \
    mv target/release/libnsm.so /usr/lib64 && \
    mv target/release/nsm.h /usr/include

RUN git clone --depth 1 -b v0.2.1 https://github.com/aws/aws-nitro-enclaves-sdk-c && \
    cmake3 -DCMAKE_PREFIX_PATH=/usr -DCMAKE_INSTALL_PREFIX=/usr -GNinja \
	-S aws-nitro-enclaves-sdk-c -B aws-nitro-enclaves-sdk-c/build && \
    cmake3 --build aws-nitro-enclaves-sdk-c/build --parallel $(nproc) --target install

# Test
FROM builder as test
RUN cmake3 --build aws-nitro-enclaves-sdk-c/build --target test

# kmstool-enclave
FROM amazonlinux as kmstool-enclave

RUN rpm -e python python-libs python-urlgrabber python2-rpm pygpgme pyliblzma python-iniparse pyxattr python-pycurl amazon-linux-extras yum yum-metadata-parser yum-plugin-ovl yum-plugin-priorities
COPY --from=builder /usr/lib64/libnsm.so /usr/lib64/libnsm.so
COPY --from=builder /usr/bin/kmstool_enclave /kmstool_enclave
ARG REGION
ARG ENDPOINT
ENV REGION=${REGION}
ENV ENDPOINT=${ENDPOINT}
CMD ["/kmstool_enclave"]

# kmstool-instance
FROM amazonlinux as kmstool-instance

RUN rpm -e python python-libs python-urlgrabber python2-rpm pygpgme pyliblzma python-iniparse pyxattr python-pycurl amazon-linux-extras yum yum-metadata-parser yum-plugin-ovl yum-plugin-priorities
COPY --from=builder /usr/lib64/libnsm.so /usr/lib64/libnsm.so
COPY --from=builder /usr/bin/kmstool_instance /kmstool_instance
CMD ["/kmstool_instance"]