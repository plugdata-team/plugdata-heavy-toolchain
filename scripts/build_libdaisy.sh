#!/bin/bash

if [[ "$OSTYPE" == "darwin"* ]]; then
    URL="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-bet1/binrel/arm-gnu-toolchain-12.2.mpacbti-bet1-darwin-x86_64-arm-none-eabi.tar.xz?rev=84494f738c6349fe84e509e91713f409&hash=F740DA913B3F2DADEC857F189AC97F76"
elif [[ $(uname -m) == "aarch64" ]]; then
    URL="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-bet1/binrel/arm-gnu-toolchain-12.2.mpacbti-bet1-aarch64-arm-none-eabi.tar.xz?rev=cd13d8fc408f42d680fcccc26281d945&hash=DD68E49B16AFE10346AE2B6D0AF4E23A"
else
    URL="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-bet1/binrel/arm-gnu-toolchain-12.2.mpacbti-bet1-x86_64-arm-none-eabi.tar.xz?rev=bad6fbd075214a34b48ddbf57e741249&hash=F87A67141928852E079463E67E2B7A02"
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
cp -rf tmp/arm-gnu-*/lib ./Heavy/lib
cp -rf tmp/arm-gnu-*/libexec ./Heavy/libexec
cp -rf tmp/arm-gnu-*/share ./Heavy/share
cp -rf tmp/arm-gnu-*/include ./Heavy/include
cp -rf tmp/arm-gnu-*/arm-none-eabi ./Heavy/arm-none-eabi

cp -rf ./resources/heavy-static.a ./Heavy/lib/heavy-static.a
cp -rf ./resources/daisy_makefile ./Heavy/utils/daisy_makefile

cp -f $(which make) Heavy/bin/make

cd ./libDaisy/
make GCC_PATH=../Heavy/bin/
cd ..

cp -rf ./libDaisy ./Heavy/utils/libDaisy