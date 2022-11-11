#!/bin/bash

mkdir -p Heavy/usr/bin
mkdir -p Heavy/usr/lib
mkdir -p Heavy/usr/include

cp $(which make) Heavy/usr/bin/make

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

cp $(which arm-none-eabi-gcc) Heavy/usr/bin/arm-none-eabi-gcc
cp $(which dfu-util) Heavy/usr/bin/dfu-util
cp $(which openocd) Heavy/usr/bin/openocd

else

# https://askubuntu.com/a/1371525
# https://developer.arm.com/downloads/-/gnu-rm

VER=${VER:-'10.3-2021.10'}

URL=https://developer.arm.com/-/media/Files/downloads/gnu/${VER}/binrel/gcc-arm-${VER}-x86_64-arm-none-eabi.tar.xz

echo "Downloading arm-none-eabi-gcc"
curl -fSL -A "Mozilla/4.0" -o gcc-arm-none-eabi.tar "$URL"

echo "Extracting..."
mkdir tmp
pushd tmp
tar -xf ../gcc-arm-none-eabi.tar
popd
rm gcc-arm-none-eabi.tar

mv tmp/gcc-arm-*/* gcc-arm-none-eabi/usr/

fi


cd ./libDaisy/
make
cd ..

cp -r ./libDaisy Heavy/usr/opt/libDaisy
