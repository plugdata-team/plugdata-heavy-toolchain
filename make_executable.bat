python -m ensurepip
python -m pip install hvcc
python -m pip install pyinstaller

FOR /F "tokens=*" %%g IN ('python -m site --user-site') do (SET PYTHON_SITE=%%g)

python pyinstaller --noconfirm --windowed --paths %PYTHON_SITE% .\hvcc\hvcc\__init__.py --add-data="./hvcc/hvcc/generators:./generators" --add-data="./hvcc/hvcc/core:./hvcc/core" --add-data="./hvcc/hvcc/generators:./hvcc/generators" --add-data="./hvcc/hvcc/interpreters:./hvcc/interpreters"

move .\dist\__init__.exe ./Heavy.exe

del /s /q .\dist\*
del /s /q .\build\*
del /s /q .\__init__.spec