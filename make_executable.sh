python3 -m ensurepip
python3 -m pip install hvcc
python3 -m pip install pyinstaller

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    python3 pyinstaller -F --noconfirm --windowed --paths $(python3 -m site --user-site) ./hvcc/hvcc/__init__.py --add-data="./hvcc/*:./hvcc"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    python3 pyinstaller -F --noconfirm --windowed --target-architecture universal2 --paths $(python3 -m site --user-site) ./hvcc/hvcc/__init__.py --add-data="./hvcc/*:./hvcc" --add-data="./hvcc/*:./"
fi

mv ./dist/__init__ ./Heavy
rm -rf ./dist
rm -rf ./build
rm -rf ./__init__.spec
chmod +x ./Heavy