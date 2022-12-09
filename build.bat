mkdir "Heavy"

:: Expand minGW environment, for command line utilities and compilation utilities
powershell -Command "Expand-Archive resources\minGW.zip -Force -DestinationPath .\Heavy"

copy resources\heavy-static.a Heavy\lib\heavy-static.a
copy resources\daisy_makefile Heavy\etc\daisy_makefile
xcopy /E /H /C /I resources\usb_driver Heavy\etc\usb_driver

:: Remove unnecessary target platforms from compiler
mkdir "Heavy\usr\arm-none-eabi\lib\temp"
move "Heavy\usr\arm-none-eabi\lib\thumb\v7e-m+dp" "Heavy\arm-none-eabi\usr\lib\temp\v7e-m+dp"
rmdir /S /Q "Heavy\usr\arm-none-eabi\lib\thumb"
rename "Heavy\usr\arm-none-eabi\lib\temp" "thumb"

mkdir "Heavy\usr\lib\gcc\arm-none-eabi\12.2.0\temp"
move "Heavy\usr\lib\gcc\arm-none-eabi\12.2.0\thumb\v7e-m+dp" "Heavy\usr\lib\gcc\arm-none-eabi\12.2.0\temp\v7e-m+dp"
rmdir /S /Q "Heavy\usr\lib\gcc\arm-none-eabi\12.2.0\thumb"
rename "Heavy\usr\lib\gcc\arm-none-eabi\12.2.0\temp" "thumb"

del /S /Q ".\Heavy\usr\arm-none-eabi\lib\arm"

:: Pre-build libdaisy
cd libDaisy

echo ../Heavy/bin/make.exe GCC_PATH=../Heavy/bin> build.sh
..\Heavy\bin\sh.exe --login build.sh
cd ..

xcopy /E /H /C /I libDaisy Heavy\usr\lib\libDaisy
xcopy /E /H /C /I DPF Heavy\usr\lib\DPF

:: Package heavy using pyinstaller
python -m ensurepip
python -m pip install hvcc
python -m pip install pyinstaller

FOR /F "tokens=*" %%g IN ('python -m site --user-site') do (SET PYTHON_SITE=%%g)

python resources\run_pyinstaller.py -n Heavy --noconfirm  --windowed --paths %PYTHON_SITE% .\hvcc\hvcc\__init__.py --collect-data json2daisy --add-data=".\hvcc\hvcc\generators;.\generators" --add-data=".\hvcc\hvcc\core;.\hvcc\core" --add-data=".\hvcc\hvcc\generators;.\hvcc\generators" --add-data=".\hvcc\hvcc\interpreters;.\hvcc\interpreters"

copy .\dist\Heavy\json2daisy\resources\component_defs.json .\dist\Heavy\json2daisy\resources\seed.json
move .\dist\Heavy .\Heavy\usr\bin\

del /s /q .\dist\*
del /s /q .\build\*
del /s /q .\__init__.spec

cp VERSION Heavy\VERSION