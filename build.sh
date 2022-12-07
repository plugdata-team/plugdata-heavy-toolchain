#!/bin/bash

# Download arm compiler for compiling on daisy
if [[ "$OSTYPE" == "darwin"* ]]; then
    URL="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-bet1/binrel/arm-gnu-toolchain-12.2.mpacbti-bet1-darwin-x86_64-arm-none-eabi.tar.xz"
# Aarch64 Linux
elif [[ $(uname -m) == "aarch64" ]]; then
    URL="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-bet1/binrel/arm-gnu-toolchain-12.2.mpacbti-bet1-aarch64-arm-none-eabi.tar.xz"
# x86_64 Linux
else
    URL="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-bet1/binrel/arm-gnu-toolchain-12.2.mpacbti-bet1-x86_64-arm-none-eabi.tar.xz"
fi

echo "Downloading arm-none-eabi-gcc"
curl -fSL -A "Mozilla/4.0" -o gcc-arm-none-eabi.tar.xz $URL

echo "Extracting..."
mkdir tmp
pushd tmp
tar -xf ../gcc-arm-none-eabi.tar.xz
popd
rm gcc-arm-none-eabi.tar.xz

mkdir Heavy
cp -rf tmp/arm-gnu-*/bin ./Heavy
cp -rf tmp/arm-gnu-*/lib ./Heavy
cp -rf tmp/arm-gnu-*/libexec ./Heavy
cp -rf tmp/arm-gnu-*/share ./Heavy
cp -rf tmp/arm-gnu-*/include ./Heavy
cp -rf tmp/arm-gnu-*/arm-none-eabi ./Heavy

if [[ "$OSTYPE" == "darwin"* ]]; then
    curl -fSL -A "Mozilla/4.0" -o homebrew.zip https://github.com/Homebrew/brew/archive/refs/tags/3.6.13.zip
    unzip homebrew.zip
    mv brew-3.6.13 homebrew
    ./homebrew/bin/brew install llvm
    cp -rf ./homebrew/bin/* ./Heavy/bin
    cp -rf ./homebrew/lib/* ./Heavy/lib
    cp -rf ./homebrew/Cellar ./Heavy/Cellar
else

git clone https://github.com/minos-org/minos-static.git
./minos-static/static-get -x gcc
echo $(ls)
cp ./gcc* ./Heavy/bin
cp ./g++* ./Heavy/bin
fi

# Reduce package size by only including the daisy platform tools
mkdir -p "./Heavy/arm-none-eabi/lib/temp/"
mv -f "./Heavy/arm-none-eabi/lib/thumb/v7e-m+dp" "./Heavy/arm-none-eabi/lib/temp" 
rm -rf "./Heavy/arm-none-eabi/lib/thumb"
mv -f "./Heavy/arm-none-eabi/lib/temp" "./Heavy/arm-none-eabi/lib/thumb"

mkdir -p "./Heavy/lib/gcc/arm-none-eabi/12.2.0/temp"
mv "./Heavy/lib/gcc/arm-none-eabi/12.2.0/thumb/v7e-m+dp" "./Heavy/lib/gcc/arm-none-eabi/12.2.0/temp/v7e-m+dp"
rm -rf "./Heavy/lib/gcc/arm-none-eabi/12.2.0/thumb"
mv "./Heavy/lib/gcc/arm-none-eabi/12.2.0/temp" "./Heavy/lib/gcc/arm-none-eabi/12.2.0/thumb"

rm -rf "./Heavy/arm-none-eabi/lib/arm"

mkdir -p ./Heavy/etc/linkers

# copy a prebuild static library for heavy
cp -rf ./resources/heavy-static.a ./Heavy/lib/heavy-static.a
cp -rf ./resources/daisy_makefile ./Heavy/etc/daisy_makefile
cp -rf ./resources/*.lds ./Heavy/etc/linkers

# copy dfu-util
cp $(which dfu-util) ./Heavy/bin/dfu-util

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

# Hack: make sure libintl is not found on macOS, when building on Github actions server!
if [[ "$CLEAR_INTL" == "1" ]]; then
rm -f /usr/local/opt/gettext/lib/libintl*.dylib
fi

./configure --disable-dependency-tracking --with-guile=no --without-libintl-prefix
./build.sh
cp make ../Heavy/bin/make
popd
rm -rf make-4.4 make-4.4.tar.gz

# Pre-build libdaisy
pushd libDaisy
make GCC_PATH=../Heavy/bin/
popd

cp -rf ./libDaisy ./Heavy/lib/libDaisy

# Package Heavy with pyinstaller
python3 -m ensurepip
python3 -m pip install hvcc
python3 -m pip install pyinstaller

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    python3 ./resources/run_pyinstaller.py -n Heavy --noconfirm --windowed --paths $(python3 -m site --user-site) ./hvcc/hvcc/__init__.py --collect-data json2daisy --add-data="./hvcc/hvcc/generators:./generators" --add-data="./hvcc/hvcc/core:./hvcc/core" --add-data="./hvcc/hvcc/generators:./hvcc/generators" --add-data="./hvcc/hvcc/interpreters:./hvcc/interpreters"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    python3 ./resources/run_pyinstaller.py -n Heavy --noconfirm --windowed --paths $(python3 -m site --user-site) --target-architecture universal2 ./hvcc/hvcc/__init__.py --collect-data json2daisy --add-data="./hvcc/hvcc/generators:./generators" --add-data="./hvcc/hvcc/core:./hvcc/core" --add-data="./hvcc/hvcc/generators:./hvcc/generators" --add-data="./hvcc/hvcc/interpreters:./hvcc/interpreters"
fi

cp ./dist/Heavy/json2daisy/resources/component_defs.json ./dist/Heavy/json2daisy/resources/seed.json

mv ./dist/Heavy Heavy/bin/Heavy

rm -rf ./dist
rm -rf ./build
rm -rf ./Heavy.spec

cp VERSION ./Heavy/VERSION
