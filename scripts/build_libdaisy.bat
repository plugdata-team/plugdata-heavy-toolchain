set URL="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-bet1/binrel/arm-gnu-toolchain-12.2.mpacbti-bet1-mingw-w64-i686-arm-none-eabi.zip"

if "%1"=="1" powershell -Command "Invoke-WebRequest %URL% -OutFile arm-none-eabi-gcc.zip"
powershell -Command "Expand-Archive arm-none-eabi-gcc.zip -Force -DestinationPath .\tmp"

move tmp\arm-gnu-* .\Heavy

copy resources\heavy-static.a Heavy\lib\heavy-static.a
copy resources\daisy_makefile Heavy\share\daisy_makefile

mkdir "Heavy\arm-none-eabi\lib\temp"
move "Heavy\arm-none-eabi\lib\thumb\v7e-m+dp" "Heavy\arm-none-eabi\lib\temp\v7e-m+dp"
del /S /Q "Heavy\arm-none-eabi\lib\thumb"
move "Heavy\arm-none-eabi\lib\temp" "Heavy\arm-none-eabi\lib\thumb"

mkdir "Heavy\lib\gcc\arm-none-eabi\12.2.0\temp"
move "\Heavy\lib\gcc\arm-none-eabi\12.2.0\thumb\v7e-m+dp" "Heavy\lib\gcc\arm-none-eabi\12.2.0\temp\v7e-m+dp"
del /S /Q "Heavy\lib\gcc\arm-none-eabi\12.2.0\thumb"
move "Heavy\lib\gcc\arm-none-eabi\12.2.0\temp" "Heavy\lib\gcc\arm-none-eabi\12.2.0\thumb"

del /S /Q ".\Heavy\arm-none-eabi\lib\arm"

FOR /F "tokens=* USEBACKQ" %%F IN (`where make`) DO (
set make_location=%%F
)

copy %make_location% Heavy\bin\make.exe

cd libDaisy
make GCC_PATH=..\Heavy\bin\
cd ..

xcopy /E /H /C /I libDaisy Heavy\lib\libDaisy