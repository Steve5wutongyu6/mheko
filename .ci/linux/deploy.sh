#!/usr/bin/env sh

set -ex

APP=mheko
DIR=${APP}.AppDir
# unused but may be useful...
#TAG=$(git tag -l --points-at HEAD)

# Set up AppImage structure.
for d in bin lib share/pixmaps share/applications
do
    mkdir -p ${DIR}/usr/$d
done

# Copy resources.
cp build/mheko ${DIR}/usr/bin
cp build/resources/mheko.desktop ${DIR}/usr/share/applications/mheko.desktop
cp resources/nheko.png ${DIR}/usr/share/pixmaps/mheko.png

for iconSize in 16 32 48 64 128 256 512; do
    IconDir=${DIR}/usr/share/icons/hicolor/${iconSize}x${iconSize}/apps
    mkdir -p ${IconDir}
    cp resources/nheko-${iconSize}.png ${IconDir}/mheko.png
done

# Only download the file when not already present
if ! [ -f linuxdeployqt-6-x86_64.AppImage ] ; then
	wget -c "https://github.com/probonopd/linuxdeployqt/releases/download/6/linuxdeployqt-6-x86_64.AppImage"
fi
chmod a+x linuxdeployqt*.AppImage

unset QTDIR
unset QT_PLUGIN_PATH
unset LD_LIBRARY_PATH

ARCH=$(uname -m)
export ARCH
LD_LIBRARY_PATH=$(pwd)/.deps/usr/lib/:/usr/local/lib/:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH

for res in ./linuxdeployqt*.AppImage
do
    linuxdeployqt=$res
done

./"$linuxdeployqt" ${DIR}/usr/share/applications/*.desktop -unsupported-allow-new-glibc -bundle-non-qt-libs -qmldir=./resources/qml -appimage

chmod +x mheko-*x86_64.AppImage

mkdir artifacts
cp mheko-*x86_64.AppImage artifacts/

if [ -n "$VERSION" ]; then
    # commented out for now, as AppImage file appears to already contain the version.
    #mv mheko-*x86_64.AppImage mheko-${VERSION}-x86_64.AppImage
    echo "mheko-${VERSION}-x86_64.AppImage"
fi
