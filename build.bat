mkdir "Heavy"

:: Expand minGW environment, for command line utilities and compilation utilities
powershell -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://github.com/plugdata-team/plugdata-heavy-toolchain/releases/download/minGW_package/minGW.zip -OutFile minGW.zip"
powershell -Command "$ProgressPreference = 'SilentlyContinue'; Expand-Archive minGW.zip -Force -DestinationPath .\Heavy"

mkdir .\Heavy\usr\etc\linkers

copy resources\heavy-static.a Heavy\usr\lib\heavy-static.a
copy resources\daisy_makefile Heavy\usr\etc\daisy_makefile
copy .\resources\*.lds .\Heavy\usr\etc\linkers
copy .\resources\simple.json .\Heavy\usr\etc\simple.json
copy .\resources\terrarium.json .\Heavy\usr\etc\terrarium.json
copy .\resources\versio.json .\Heavy\usr\etc\versio.json
copy .\resources\hothouse.json .\Heavy\usr\etc\hothouse.json
xcopy /E /H /C /I resources\usb_driver Heavy\usr\etc\usb_driver

del /S /Q ".\Heavy\usr\arm-none-eabi\lib\arm"

:: Pre-build libdaisy
cd libdaisy

echo ../Heavy/usr/bin/make.exe GCC_PATH=../Heavy/usr/bin> build.sh
..\Heavy\usr\bin\bash.exe --login build.sh
cd ..

xcopy /E /H /C /I libdaisy Heavy\usr\lib\libdaisy
xcopy /E /H /C /I dpf Heavy\usr\lib\dpf
xcopy /E /H /C /I dpf-widgets Heavy\usr\lib\dpf-widgets

:: Package heavy using pyinstaller
python -m ensurepip
python -m pip install poetry poetry-pyinstaller-plugin


cd hvcc
poetry build
cd ..

mkdir .\Heavy\usr\bin\Heavy\

move .\hvcc\dist\pyinstaller\win_amd64\Heavy.exe .\Heavy\usr\bin\Heavy\

cp VERSION Heavy\VERSION
