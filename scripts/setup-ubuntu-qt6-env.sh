#!/usr/bin/env bash

set -euo pipefail

QT_VERSION="${QT_VERSION:-6.8.3}"
QT_OUTPUT_DIR="${QT_OUTPUT_DIR:-$HOME/Qt}"
QT_ARCH="${QT_ARCH:-linux_gcc_64}"
QT_MODULES=(
    qtlocation
    qtimageformats
    qtmultimedia
    qtpositioning
    qtshadertools
)

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    ccache \
    pkg-config \
    git \
    curl \
    ca-certificates \
    unzip \
    zip \
    python3-pip \
    pipx \
    ripgrep \
    asciidoc-base \
    libevent-dev \
    libspdlog-dev \
    libre2-dev \
    liblmdb-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libolm-dev \
    libcmark-dev \
    nlohmann-json3-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer-plugins-bad1.0-dev \
    libpulse-dev \
    libxcb-ewmh-dev \
    libxkbcommon-dev \
    libsecret-1-dev

if ! command -v aqt >/dev/null 2>&1; then
    pipx install aqtinstall
fi

if [[ ! -d "${QT_OUTPUT_DIR}/${QT_VERSION}/gcc_64/lib/cmake/Qt6" ]]; then
    aqt install-qt --outputdir "${QT_OUTPUT_DIR}" linux desktop "${QT_VERSION}" "${QT_ARCH}" -m "${QT_MODULES[@]}"
fi
