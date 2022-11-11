#!/bin/bash

mkdir -p Heavy/usr/bin
mkdir -p Heavy/usr/lib
mkdir -p Heavy/usr/utils
mkdir -p Heavy/usr/include

if [[ "$OSTYPE" == "darwin"* ]]; then
    
# path variable
echo "Installing DaisyToolchain"
SCRIPTPATH=./scripts

# install brew
if ! command -v brew &> /dev/null
then
    echo "Installing Homebrew: Follow onscreen instructions"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

#upgrade homebrew
echo "Updating Homebrew"
brew update

echo "Installing packages with Homebrew"
brew install openocd dfu-util
brew install $SCRIPTPATH/gcc-arm-embedded.rb --cask

cp -f $(which arm-none-eabi-gcc) Heavy/usr/bin/arm-none-eabi-gcc
cp -f $(which dfu-util) Heavy/usr/bin/dfu-util
cp -f $(which openocd) Heavy/usr/bin/openocd

else

# https://askubuntu.com/a/1371525
# https://developer.arm.com/downloads/-/gnu-rm

URL="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-bet1/binrel/arm-gnu-toolchain-12.2.mpacbti-bet1-x86_64-arm-none-eabi.tar.xz?rev=bad6fbd075214a34b48ddbf57e741249&hash=F87A67141928852E079463E67E2B7A02"

echo "Downloading arm-none-eabi-gcc"
#curl -fSL -A "Mozilla/4.0" -o gcc-arm-none-eabi.tar.xz $URL

echo "Extracting..."
mkdir tmp
pushd tmp
tar -xf ../gcc-arm-none-eabi.tar.xz
popd
rm gcc-arm-none-eabi.tar.xz

mv -f tmp/arm-gnu-*/* ./Heavy/usr/
cp -f $(which make) Heavy/usr/bin/make

sudo ln -s /usr/bin/arm-none-eabi-gcc /usr/bin/arm-none-eabi-gcc 
sudo ln -s /usr/bin/arm-none-eabi-g++ /usr/bin/arm-none-eabi-g++
sudo ln -s /usr/bin/arm-none-eabi-gdb /usr/bin/arm-none-eabi-gdb
sudo ln -s /usr/bin/arm-none-eabi-size /usr/bin/arm-none-eabi-size
sudo ln -s /usr/bin/arm-none-eabi-objcopy /usr/bin/arm-none-eabi-objcopy

fi

cd ./libDaisy/
make
cd ..

cp -rf ./libDaisy ./Heavy/usr/utils/libDaisy