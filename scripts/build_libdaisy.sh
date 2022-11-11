#!/bin/bash

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

fi

mkdir -p Heavy/usr/bin
mkdir -p Heavy/usr/lib
mkdir -p Heavy/usr/include

cp $(which arm-none-eabi-gcc) Heavy/usr/bin/arm-none-eabi-gcc
cp $(which dfu-util) Heavy/usr/bin/dfu-util
cp $(which openocd) Heavy/usr/bin/openocd
cp $(which make) Heavy/usr/bin/make

cd ./libDaisy/
make
cd ..

cp -r ./libDaisy Heavy/usr/opt/libDaisy