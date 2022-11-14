git clone --recursive https://github.com/electro-smith/DaisyToolchain

set URL="https://github.com/git-for-windows/git/releases/download/v2.38.1.windows.1/MinGit-2.38.1-64-bit.zip"

move DaisyToolchain\windows Heavy
copy resources\heavy-static.a Heavy\lib\heavy-static.a
copy resources\daisy_makefile Heavy\share\daisy_makefile

powershell -Command "Invoke-WebRequest %URL% -OutFile MinGit.zip"
powershell -Command "Expand-Archive MinGit.zip -Force -DestinationPath .\tmp"

move tmp\mingw64 Heavy\mingw64
move tmp\etc Heavy\etc
move tmp\usr Heavy\usr
move tmp\cmd Heavy\cmd

mkdir "Heavy\arm-none-eabi\lib\temp"
move "Heavy\arm-none-eabi\lib\thumb\v7e-m+dp" "Heavy\arm-none-eabi\lib\temp\v7e-m+dp"
rmdir /S /Q "Heavy\arm-none-eabi\lib\thumb"
rename "Heavy\arm-none-eabi\lib\temp" "thumb"

mkdir "Heavy\lib\gcc\arm-none-eabi\12.2.0\temp"
move "\Heavy\lib\gcc\arm-none-eabi\12.2.0\thumb\v7e-m+dp" "Heavy\lib\gcc\arm-none-eabi\12.2.0\temp\v7e-m+dp"
rmdir /S /Q "Heavy\lib\gcc\arm-none-eabi\12.2.0\thumb"
rename "Heavy\lib\gcc\arm-none-eabi\12.2.0\temp" "thumb"

del /S /Q ".\Heavy\arm-none-eabi\lib\arm"

cd libDaisy
./Heavy/bin/make.exe GCC_PATH=../Heavy/bin
cd ..

xcopy /E /H /C /I libDaisy Heavy\lib\libDaisy
