python3 -m ensurepip
python3 -m pip install hvcc
python3 -m pip install pyinstaller
python3 pyinstaller -F --noconfirm --windowed --paths $(python3 -m site --user-site) ./hvcc/hvcc/__init__.py --add-data="./hvcc/*:./hvcc"
mv ./dist/__init__ ./Heavy-$1
rm -rf ./dist
rm -rf ./build
rm -rf ./__init__.spec