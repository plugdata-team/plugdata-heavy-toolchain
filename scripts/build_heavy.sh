#!/bin/bash

python3 -m ensurepip
python3 -m pip install hvcc
python3 -m pip install pyinstaller

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    python3 pyinstaller -n Heavy --noconfirm  --windowed --paths $(python3 -m site --user-site) ./hvcc/hvcc/__init__.py --collect-data json2daisy --add-data="./hvcc/hvcc/generators:./generators" --add-data="./hvcc/hvcc/core:./hvcc/core" --add-data="./hvcc/hvcc/generators:./hvcc/generators" --add-data="./hvcc/hvcc/interpreters:./hvcc/interpreters"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    python3 pyinstaller -n Heavy  --noconfirm --windowed --target-architecture universal2 --paths $(python3 -m site --user-site) ./hvcc/hvcc/__init__.py --collect-data json2daisy  --add-data="./hvcc/hvcc/generators:./generators" --add-data="./hvcc/hvcc/core:./hvcc/core" --add-data="./hvcc/hvcc/generators:./hvcc/generators" --add-data="./hvcc/hvcc/interpreters:./hvcc/interpreters"
fi

mv ./dist/Heavy ./Heavy
rm -rf ./dist
rm -rf ./build
rm -rf ./Heavy.spec
chmod +x ./Heavy/Heavy