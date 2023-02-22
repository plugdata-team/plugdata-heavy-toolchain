mkdir "Heavy"

:: Expand minGW environment, for command line utilities and compilation utilities
powershell -Command "Invoke-WebRequest -Uri https://github.com/plugdata-team/plugdata-heavy-toolchain/releases/download/minGW_package/minGW.zip -OutFile minGW.zip"
powershell -Command "Expand-Archive minGW.zip -Force -DestinationPath .\Heavy"

mkdir .\Heavy\usr\etc\linkers

copy resources\heavy-static.a Heavy\usr\lib\heavy-static.a
copy resources\daisy_makefile Heavy\usr\etc\daisy_makefile
copy .\resources\*.lds .\Heavy\usr\etc\linkers
copy .\resources\simple.json .\Heavy\usr\etc\simple.json
xcopy /E /H /C /I resources\usb_driver Heavy\usr\etc\usb_driver

:: Remove unnecessary target platforms from compiler
mkdir "Heavy\usr\arm-none-eabi\lib\temp"
move "Heavy\usr\arm-none-eabi\lib\thumb\v7e-m+dp" "Heavy\usr\arm-none-eabi\lib\temp\v7e-m+dp"
rmdir /S /Q "Heavy\usr\arm-none-eabi\lib\thumb"
rename "Heavy\usr\arm-none-eabi\lib\temp" "thumb"

mkdir "Heavy\usr\lib\gcc\arm-none-eabi\12.2.0\temp"
move "Heavy\usr\lib\gcc\arm-none-eabi\12.2.0\thumb\v7e-m+dp" "Heavy\usr\lib\gcc\arm-none-eabi\12.2.0\temp\v7e-m+dp"
rmdir /S /Q "Heavy\usr\lib\gcc\arm-none-eabi\12.2.0\thumb"
rename "Heavy\usr\lib\gcc\arm-none-eabi\12.2.0\temp" "thumb"

del /S /Q ".\Heavy\usr\arm-none-eabi\lib\arm"

:: Pre-build libdaisy
cd libdaisy

echo ../Heavy/usr/bin/make.exe GCC_PATH=../Heavy/usr/bin> build.sh
..\Heavy\usr\bin\bash.exe --login build.sh
cd ..

xcopy /E /H /C /I libdaisy Heavy\usr\lib\libdaisy
xcopy /E /H /C /I dpf Heavy\usr\lib\dpf

:: Package heavy using pyinstaller
python -m ensurepip
python -m pip install hvcc
python -m pip install pyinstaller==5.7.0

FOR /F "tokens=*" %%g IN ('python -m site --user-site') do (SET PYTHON_SITE=%%g)

python resources\run_pyinstaller.py -n Heavy --noconfirm  --windowed --paths %PYTHON_SITE% .\hvcc\hvcc\__init__.py --collect-data json2daisy --add-data=".\hvcc\hvcc\generators;.\generators" --add-data=".\hvcc\hvcc\core;.\hvcc\core" --add-data=".\hvcc\hvcc\generators;.\hvcc\generators" --add-data=".\hvcc\hvcc\interpreters;.\hvcc\interpreters"

copy .\dist\Heavy\json2daisy\resources\component_defs.json .\dist\Heavy\json2daisy\resources\seed.json
move .\dist\Heavy .\Heavy\usr\bin\

del /s /q .\dist\*
del /s /q .\build\*
del /s /q .\__init__.spec

cp VERSION Heavy\VERSION