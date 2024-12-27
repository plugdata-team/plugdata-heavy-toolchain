#!/bin/bash

export MACOSX_DEPLOYMENT_TARGET="10.6"

# Download arm compiler for compiling on daisy
if [[ "$OSTYPE" == "darwin"* ]]; then
    URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/10-2020q4/gcc-arm-none-eabi-10-2020-q4-major-mac.tar.bz2"
# Aarch64 Linux
elif [[ $(uname -m) == "aarch64" ]]; then
    URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/10-2020q4/gcc-arm-none-eabi-10-2020-q4-major-aarch64-linux.tar.bz2"
# x86_64 Linux
else
    URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/10-2020q4/gcc-arm-none-eabi-10-2020-q4-major-x86_64-linux.tar.bz2"
fi

curl -fSL -A "Mozilla/4.0" -o gcc-arm-none-eabi.tar.bz2 $URL

echo "Extracting..."
mkdir gcc-arm-none-eabi
pushd gcc-arm-none-eabi
tar -xjf ../gcc-arm-none-eabi.tar.bz2
popd
rm gcc-arm-none-eabi.tar.bz2

mkdir Heavy
cp -rf gcc-arm-none-eabi/gcc-arm-*/bin ./Heavy
cp -rf gcc-arm-none-eabi/gcc-arm-*/lib ./Heavy
# cp -rf gcc-arm-none-eabi/gcc-arm-*/libexec ./Heavy
cp -rf gcc-arm-none-eabi/gcc-arm-*/share ./Heavy
# cp -rf gcc-arm-none-eabi/gcc-arm-*/include ./Heavy
cp -rf gcc-arm-none-eabi/gcc-arm-*/arm-none-eabi ./Heavy

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    curl -fSL -A "Mozilla/4.0" -o  x86_64-anywhere-linux-gnu-v5.tar.xz https://github.com/theopolis/build-anywhere/releases/download/v5/x86_64-anywhere-linux-gnu-v5.tar.xz

    mkdir build-anywhere
    pushd build-anywhere
    tar -xf ../x86_64-anywhere-linux-gnu-v5.tar.xz

    pushd x86_64-anywhere-linux-gnu
    # Fix: use gcc instead of clang, for compactness
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/include/llvm*
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/include/clang*
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/share/clang
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/lib/libclang
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/lib/cmake/llvm
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/lib/cmake/clang
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/lib/clang
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/bin/llvm-cov
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/bin/llvm-*
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/bin/clang-*
    rm ./x86_64-anywhere-linux-gnu/sysroot/usr/lib/libclang.so.8
    rm ./x86_64-anywhere-linux-gnu/sysroot/usr/lib/libLLVM-8.so
    rm ./x86_64-anywhere-linux-gnu/sysroot/usr/bin/git-clang-format
    rm ./x86_64-anywhere-linux-gnu/sysroot/usr/bin/c-index-test
    rm ./x86_64-anywhere-linux-gnu/sysroot/usr/bin/diagtool
    rm ./x86_64-anywhere-linux-gnu/sysroot/usr/bin/wasm-ld

    # more cleanup
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/src*
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/sbin*
    rm -rf ./x86_64-anywhere-linux-gnu/sysroot/usr/share/doc*
    rm -rf ./share/doc*

    # copy scripts

    cp ../../resources/anywhere-setup.sh ./scripts/anywhere-setup.sh
    cp ../../resources/install_udev_rule.sh ./scripts/install_udev_rule.sh
    cp ../../resources/askpass.sh ./scripts/askpass.sh

    popd
    popd

    rsync -a ./build-anywhere/x86_64-anywhere-linux-gnu/ ./Heavy/
fi

# Reduce package size by only including the daisy platform tools
mkdir -p "./Heavy/arm-none-eabi/lib/temp/"
# for Daisy
mv -f "./Heavy/arm-none-eabi/lib/thumb/v7e-m+dp" "./Heavy/arm-none-eabi/lib/temp"
# for OWL
mv -f "./Heavy/arm-none-eabi/lib/thumb/v7e-m+fp" "./Heavy/arm-none-eabi/lib/temp"

rm -rf "./Heavy/arm-none-eabi/lib/thumb"
mv -f "./Heavy/arm-none-eabi/lib/temp" "./Heavy/arm-none-eabi/lib/thumb"


mkdir -p "./Heavy/lib/gcc/arm-none-eabi/10.2.1/temp"
mv "./Heavy/lib/gcc/arm-none-eabi/10.2.1/thumb/v7e-m+dp" "./Heavy/lib/gcc/arm-none-eabi/10.2.1/temp/v7e-m+dp"
mv "./Heavy/lib/gcc/arm-none-eabi/10.2.1/thumb/v7e-m+fp" "./Heavy/lib/gcc/arm-none-eabi/10.2.1/temp/v7e-m+fp"
rm -rf "./Heavy/lib/gcc/arm-none-eabi/10.2.1/thumb"
mv "./Heavy/lib/gcc/arm-none-eabi/10.2.1/temp" "./Heavy/lib/gcc/arm-none-eabi/10.2.1/thumb"

rm -rf "./Heavy/arm-none-eabi/lib/arm"

mkdir -p ./Heavy/etc/linkers

# copy a prebuild static library for heavy
cp -rf ./resources/heavy-static.a ./Heavy/lib/heavy-static.a
cp -rf ./resources/daisy_makefile ./Heavy/etc/daisy_makefile
cp -rf ./resources/*.lds ./Heavy/etc/linkers
cp ./resources/simple.json ./Heavy/etc/simple.json
cp ./resources/terrarium.json ./Heavy/etc/terrarium.json
cp ./resources/versio.json ./Heavy/etc/versio.json
cp ./resources/hothouse.json ./Heavy/etc/hothouse.json

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Get libasound
    TEMP_DEB2="$(mktemp)"
    wget -O "$TEMP_DEB2" 'http://ftp.de.debian.org/debian/pool/main/a/alsa-lib/libasound2_1.1.3-5_amd64.deb'
    ar x "$TEMP_DEB2"
    tar xvf data.tar.xz
    cp ./usr/lib/x86_64-linux-gnu/libasound.so.2.0.0 ./Heavy/x86_64-anywhere-linux-gnu/sysroot/lib/libasound.so
fi

# copy dfu-util
cp $(which dfu-util) ./Heavy/bin/dfu-util
cp $(which dfu-prefix) ./Heavy/bin/dfu-prefix
cp $(which dfu-suffix) ./Heavy/bin/dfu-suffix

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    cp "$(ldconfig -p | grep libusb-1.0.so | tr ' ' '\n' | grep /)" ./Heavy/lib/libusb-1.0.so
    # Make sure it can find libusb
    patchelf --replace-needed "libusb-1.0.so.0" "\$ORIGIN/../lib/libusb-1.0.so" "./Heavy/bin/dfu-util"
    patchelf --replace-needed "libusb-1.0.so" "\$ORIGIN/../lib/libusb-1.0.so" "./Heavy/bin/dfu-util"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    HOMEBREW_PREFIX="/usr/local"
    cp $HOMEBREW_PREFIX/opt/libusb/lib/libusb-1.0.0.dylib ./Heavy/lib/libusb-1.0.0.dylib
     # Make sure it can find libusb
    install_name_tool -change "$HOMEBREW_PREFIX/opt/libusb/lib/libusb-1.0.0.dylib" "@executable_path/../lib/libusb-1.0.0.dylib" "./Heavy/bin/dfu-util"
fi

# build a version of GNU make that has no dependencies
curl -fSL -A "Mozilla/4.0" -o make-4.4.tar.gz https://ftp.gnu.org/gnu/make/make-4.4.tar.gz
tar -xf make-4.4.tar.gz
pushd make-4.4

chmod +x ./build.sh
chmod +x ./configure

# Hack: make sure libintl is not found on macOS when building on Github actions server!
if [[ "$CLEAR_INTL" == "1" ]]; then
    rm -f /usr/local/opt/gettext/lib/libintl*.dylib
fi

./configure --disable-dependency-tracking --with-guile=no --without-libintl-prefix
./build.sh
cp make ../Heavy/bin/make
popd
rm -rf make-4.4 make-4.4.tar.gz

# Pre-build libdaisy
pushd libdaisy
make GCC_PATH=../Heavy/bin/
popd

# Pre-build OWL libs (only OWL2 target for now)
pushd OwlProgram
../Heavy/bin/make libs PLATFORM=OWL2 TOOLROOT=../Heavy/bin/
popd

# Download OWL FirmwareSender from CI
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    FS_URL="https://github.com/Wasted-Audio/FirmwareSender_plugdata/releases/download/plugdata/FirmwareSender-ubuntu.zip"
    curl -fSL -A "Mozilla/4.0" -o FirmwareSender-ubuntu.zip $FS_URL
    unzip FirmwareSender-ubuntu.zip -d FirmwareSender-ubuntu
    cp ./FirmwareSender-ubuntu/FirmwareSender OwlProgram/Tools/
elif [[ "$OSTYPE" == "darwin"* ]]; then
    FS_URL="https://github.com/Wasted-Audio/FirmwareSender_plugdata/releases/download/plugdata/FirmwareSender-osx.zip"
    curl -fSL -A "Mozilla/4.0" -o FirmwareSender-osx.zip $FS_URL
    unzip FirmwareSender-osx.zip -d FirmwareSender-osx
    cp ./FirmwareSender-osx/FirmwareSender OwlProgram/Tools/
fi

# Copy all libs to toolchain
cp -rf ./libdaisy ./Heavy/lib/libdaisy
cp -rf ./OwlProgram ./Heavy/lib/OwlProgram
cp -rf ./dpf ./Heavy/lib/dpf
cp -rf ./dpf-widgets ./Heavy/lib/dpf-widgets

# Package Heavy with pyinstaller
python3 -m ensurepip
python3 -m pip install poetry poetry-pyinstaller-plugin

pushd hvcc
poetry build
popd

mkdir -p Heavy/bin/Heavy

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    mv ./hvcc/dist/pyinstaller/manylinux_2_31_x86_64/Heavy Heavy/bin/Heavy/
elif [[ "$OSTYPE" == "darwin"* ]]; then
    mv ./hvcc/dist/pyinstaller/macosx_13_0_x86_64/Heavy Heavy/bin/Heavy/
fi

cp VERSION ./Heavy/VERSION
