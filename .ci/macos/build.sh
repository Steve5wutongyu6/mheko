#!/usr/bin/env bash

set -euo pipefail

find_qt_root() {
    if [[ -n "${NHEKO_QT_ROOT:-}" ]]; then
        printf '%s\n' "${NHEKO_QT_ROOT%/}"
        return
    fi

    local matches=()
    local candidate

    for candidate in "${HOME}"/Qt/6.*/macos "${HOME}"/qt/6.*/macos; do
        if [[ -d "${candidate}" ]]; then
            matches+=("${candidate%/}")
        fi
    done

    if [[ "${#matches[@]}" -eq 0 ]]; then
        echo "Unable to locate a Qt for macOS SDK. Set NHEKO_QT_ROOT to a Qt macOS prefix." >&2
        exit 1
    fi

    printf '%s\n' "${matches[$((${#matches[@]} - 1))]}"
}

QT_BASEPATH="$(find_qt_root)"
PATH="${QT_BASEPATH}/bin:${PATH}"
export PATH

if command -v pipx >/dev/null 2>&1; then
    pipx ensurepath >/dev/null 2>&1 || true
fi

if [[ -f "${HOME}/.zshrc" ]]; then
    # Homebrew and pipx often extend PATH here on macOS runners.
    # shellcheck disable=SC1090
    . "${HOME}/.zshrc"
fi

CMAKE_PREFIX_PATH="${QT_BASEPATH}/lib/cmake${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
export CMAKE_PREFIX_PATH

if [[ -z "${CMAKE_BUILD_PARALLEL_LEVEL:-}" ]]; then
    if command -v sysctl >/dev/null 2>&1; then
        export CMAKE_BUILD_PARALLEL_LEVEL="$(sysctl -n hw.ncpu)"
    else
        export CMAKE_BUILD_PARALLEL_LEVEL="$(nproc)"
    fi
fi

export CMAKE_POLICY_VERSION_MINIMUM="3.5"

HUNTER_ROOT="${NHEKO_HUNTER_ROOT:-../.hunter}"
EXTRA_CMAKE_ARGS=()
if [[ -n "${NHEKO_CMAKE_EXTRA_ARGS:-}" ]]; then
    # Intentional word splitting to support multiple -D arguments via env.
    # shellcheck disable=SC2206
    EXTRA_CMAKE_ARGS=(${NHEKO_CMAKE_EXTRA_ARGS})
fi

cmake -GNinja -S. -Bbuild \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_INSTALL_PREFIX="nheko.temp" \
      -DHUNTER_ROOT="${HUNTER_ROOT}" \
      -DHUNTER_ENABLED=ON -DBUILD_SHARED_LIBS=OFF \
      -DKDSingleApplication_STATIC=ON -DKDSingleApplication_EXAMPLES=OFF \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo -DHUNTER_CONFIGURATION_TYPES=RelWithDebInfo \
      -DQt6_DIR="${QT_BASEPATH}/lib/cmake" \
      -DCI_BUILD=ON \
      "${EXTRA_CMAKE_ARGS[@]}"
cmake --build build
cmake --install build

(
    cd build
    if [[ ! -d qt-jdenticon ]]; then
        git clone --depth 1 https://github.com/Nheko-Reborn/qt-jdenticon.git
    fi

    cd qt-jdenticon
    qmake
    make -j "${CMAKE_BUILD_PARALLEL_LEVEL}"
    cp libqtjdenticon.dylib ../../nheko.temp/nheko.app/Contents/MacOS
    # "$(brew --prefix qt6)/bin/macdeployqt" nheko.app -always-overwrite -qmldir=../resources/qml/
    # # workaround for https://bugreports.qt.io/browse/QTBUG-100686
    # cp "$(brew --prefix brotli)/lib/libbrotlicommon.1.dylib" nheko.app/Contents/Frameworks/libbrotlicommon.1.dylib
)

mv nheko.temp/nheko.app nheko.app
