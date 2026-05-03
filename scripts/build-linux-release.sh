#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build/linux-release}"
ARTIFACT_DIR="${ARTIFACT_DIR:-${ROOT_DIR}/artifacts/mheko-linux}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${ROOT_DIR}/artifacts/mheko-linux.tar.gz}"
QT_VERSION="${QT_VERSION:-6.8.3}"
QT_ROOT="${QT_ROOT:-${HOME}/Qt/${QT_VERSION}/gcc_64}"

if [[ ! -d "${QT_ROOT}/lib/cmake/Qt6" ]]; then
    echo "Qt SDK not found at ${QT_ROOT}. Run scripts/setup-ubuntu-qt6-env.sh first or set QT_ROOT." >&2
    exit 1
fi

mkdir -p "${BUILD_DIR}" "${ROOT_DIR}/artifacts"
rm -rf "${ARTIFACT_DIR}"

if command -v nproc >/dev/null 2>&1; then
    export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}"
fi

export CMAKE_PREFIX_PATH="${QT_ROOT}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
export CCACHE_DIR="${CCACHE_DIR:-${HOME}/.cache/ccache}"
mkdir -p "${CCACHE_DIR}"

CMAKE_ARGS=(
    -GNinja
    -S "${ROOT_DIR}"
    -B "${BUILD_DIR}"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="${ARTIFACT_DIR}"
    -DCMAKE_PREFIX_PATH="${QT_ROOT}"
    -DCMAKE_C_COMPILER_LAUNCHER=ccache
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
    -DMAN=OFF
    -DJSON_ImplicitConversions=ON
    -DUSE_BUNDLED_COEURL=ON
    -DUSE_BUNDLED_MTXCLIENT=ON
    -DUSE_BUNDLED_LMDBXX=ON
    -DUSE_BUNDLED_QTKEYCHAIN=ON
    -DUSE_BUNDLED_KDSINGLEAPPLICATION=ON
)

if ! pkg-config --exists gstreamer-sdp-1.0 gstreamer-webrtc-1.0 gstreamer-gl-1.0; then
    CMAKE_ARGS+=(-DVOIP=OFF)
fi

if ! pkg-config --exists xcb xcb-ewmh; then
    CMAKE_ARGS+=(-DX11=OFF)
fi

cmake "${CMAKE_ARGS[@]}" "$@"
cmake --build "${BUILD_DIR}"
cmake --install "${BUILD_DIR}"
tar -C "$(dirname "${ARTIFACT_DIR}")" -czf "${ARCHIVE_PATH}" "$(basename "${ARTIFACT_DIR}")"
