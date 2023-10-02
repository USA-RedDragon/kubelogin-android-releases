#!/bin/bash

set -euo pipefail

# renovate: datasource=github-tags depName=int128/kubelogin
KUBELOGIN_VERSION=v1.27.0
# renovate: datasource=github-tags depName=android/ndk versioning=semver-coerced
NDK_VERSION=r26

# Clone the repo
KUBELOGIN_DIR=$(mktemp -d)
git clone -b ${KUBELOGIN_VERSION} https://github.com/int128/kubelogin.git ${KUBELOGIN_DIR} --depth 1 --single-branch >/dev/null

# Install the NDK
TMPFILE=$(mktemp)
NDKDIR=$(mktemp -d)
curl -fSsLo ${TMPFILE} https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip
unzip -qod ${NDKDIR} ${TMPFILE}
rm ${TMPFILE}

# The NDK has various Android toolchains for each API level and architecture.
# We want to use the earliest available API level for maximum compatibility
# and both aarch64 and armv7a.
# The path will be something like:
# ${NDKDIR}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang
# or
# ${NDKDIR}/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi21-clang

API_VERSION=$(
    find ${NDKDIR}/android-ndk-${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin/ -maxdepth 1 -type f -name 'aarch64-*' \
    | sed 's/.*aarch64-linux-android//' \
    | sed "s/-clang+*//" \
    | sort -n \
    | head -n 1
)

ARM_CC=${NDKDIR}/android-ndk-${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi${API_VERSION}-clang
AARCH64_CC=${NDKDIR}/android-ndk-${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android${API_VERSION}-clang

RUNDIR=$(pwd)
cd ${KUBELOGIN_DIR}

# Use the NDK to build the binary
env \
        KUBELOGIN_VERSION=${KUBELOGIN_VERSION} \
        CC=${AARCH64_CC} \
        CGO_ENABLED=1 \
        GOOS=android \
        GOARCH=arm64 \
    go build \
    -o ${RUNDIR}/kubelogin-android-arm64 \
    -ldflags '-X main.version=${KUBELOGIN_VERSION}' github.com/int128/kubelogin

env \
        KUBELOGIN_VERSION=${KUBELOGIN_VERSION} \
        CC=${ARM_CC} \
        CGO_ENABLED=1 \
        GOOS=android \
        GOARCH=arm \
    go build \
    -o ${RUNDIR}/kubelogin-android-arm \
    -ldflags '-X main.version=${KUBELOGIN_VERSION}' github.com/int128/kubelogin

cd ${RUNDIR}

rm -rf ${NDKDIR} ${KUBELOGIN_DIR}
