python3 -m ensurepip
python3 -m pip install hvcc
python3 -m pip install pyinstaller
pyinstaller -F --windowed --paths /Users/timschoen/Library/Python/3.10/lib/python/site-packages /Users/timschoen/Projecten/PlugData/Libraries/Heavy/hvcc/hvcc/__init__.py --add-data="./hvcc/*:./hvcc"
