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

find /usr/local/Caskroom/gcc-arm-embedded -type f -perm +111 -print | xargs spctl --add --label "gcc-arm-embedded"
find /usr/local/Caskroom/gcc-arm-embedded | xargs xattr -d com.apple.quarantine

fi

mkdir -p Heavy/usr/bin
mkdir -p Heavy/usr/lib
mkdir -p Heavy/usr/include

cp $(which arm-none-eabi-gcc) usr/bin/arm-none-eabi-gcc
cp $(which dfu-util) usr/bin/dfu-util
cp $(which openocd) usr/bin/openocd




