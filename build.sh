#!/bin/bash

# Download arm compiler for compiling on daisy
if [[ "$OSTYPE" == "darwin"* ]]; then
    URL="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-bet1/binrel/arm-gnu-toolchain-12.2.mpacbti-bet1-darwin-x86_64-arm-none-eabi.tar.xz"
elif [[ $(uname -m) == "aarch64" ]]; then
    URL="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-bet1/binrel/arm-gnu-toolchain-12.2.mpacbti-bet1-aarch64-arm-none-eabi.tar.xz"
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

# copy a prebuild static library for heavy
cp -rf ./resources/heavy-static.a ./Heavy/lib/heavy-static.a
cp -rf ./resources/daisy_makefile ./Heavy/share/daisy_makefile

# build a version of GNU make that has no dependencies
pushd resources/unix_make
tar -xf make-4.4.tar.gz
pushd make-4.4
chmod +x ./build.sh
chmod +x ./configure

# Hack: make sure libintl is not found on macOS, when building on Github actions server!
if [[ "$OSTYPE" == "darwin"* ]] && $GITHUB_ACTIONS_BUILD; then
rm -f /usr/local/opt/gettext/lib/libintl*.dylib
fi

./configure --disable-dependency-tracking --with-guile=no --without-libintl-prefix
./build.sh
cp make ../../../Heavy/bin/make
popd
popd

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
    python3 ./resources/pyinstaller -n Heavy --noconfirm --windowed --paths $(python3 -m site --user-site) ./hvcc/hvcc/__init__.py --collect-data json2daisy --add-data="./hvcc/hvcc/generators:./generators" --add-data="./hvcc/hvcc/core:./hvcc/core" --add-data="./hvcc/hvcc/generators:./hvcc/generators" --add-data="./hvcc/hvcc/interpreters:./hvcc/interpreters"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    python3 ./resources/pyinstaller -n Heavy --noconfirm --windowed --paths $(python3 -m site --user-site) --target-architecture universal2 ./hvcc/hvcc/__init__.py --collect-data json2daisy --add-data="./hvcc/hvcc/generators:./generators" --add-data="./hvcc/hvcc/core:./hvcc/core" --add-data="./hvcc/hvcc/generators:./hvcc/generators" --add-data="./hvcc/hvcc/interpreters:./hvcc/interpreters"
fi

cp ./dist/Heavy/json2daisy/resources/component_defs.json ./dist/Heavy/json2daisy/resources/seed.json

mv ./dist/Heavy Heavy/bin/Heavy

rm -rf ./dist
rm -rf ./build
rm -rf ./Heavy.spec

cp VERSION ./Heavy/VERSION
