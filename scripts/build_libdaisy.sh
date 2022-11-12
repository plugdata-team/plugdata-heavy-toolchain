#!/bin/bash

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

cp -rf tmp/arm-gnu-*/bin/* ./Heavy/bin
cp -rf tmp/arm-gnu-*/lib ./Heavy
cp -rf tmp/arm-gnu-*/libexec ./Heavy
cp -rf tmp/arm-gnu-*/share ./Heavy
cp -rf tmp/arm-gnu-*/include ./Heavy
cp -rf tmp/arm-gnu-*/arm-none-eabi ./Heavy

# reduce package size by only including the daisy platform tools
mkdir -p "./Heavy/arm-none-eabi/lib/temp/"
mv -f "./Heavy/arm-none-eabi/lib/thumb/v7e-m+dp" "./Heavy/arm-none-eabi/lib/temp" 
rm -rf "./Heavy/arm-none-eabi/lib/thumb"
mv -f "./Heavy/arm-none-eabi/lib/temp" "./Heavy/arm-none-eabi/lib/thumb"

mkdir -p "./Heavy/lib/gcc/arm-none-eabi/12.2.0/temp"
mv "./Heavy/lib/gcc/arm-none-eabi/12.2.0/thumb/v7e-m+dp" "./Heavy/lib/gcc/arm-none-eabi/12.2.0/temp/v7e-m+dp"
rm -rf "./Heavy/lib/gcc/arm-none-eabi/12.2.0/thumb"
mv "./Heavy/lib/gcc/arm-none-eabi/12.2.0/temp" "./Heavy/lib/gcc/arm-none-eabi/12.2.0/thumb"

rm -rf "./Heavy/arm-none-eabi/lib/arm"

cp -rf ./resources/heavy-static.a ./Heavy/lib/heavy-static.a
cp -rf ./resources/daisy_makefile ./Heavy/share/daisy_makefile

cp -f $(which make) Heavy/bin/make

pushd libDaisy
make GCC_PATH=../Heavy/bin/
popd

cp -rf ./libDaisy ./Heavy/lib/libDaisy