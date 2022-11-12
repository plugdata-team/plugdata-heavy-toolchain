
set URL="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-bet1/binrel/arm-gnu-toolchain-12.2.mpacbti-bet1-mingw-w64-i686-arm-none-eabi.zip?rev=02b9889af49c4da9bc47018c00e18eb5&hash=AE65D45D5C9377AC531CF2EDB447FA99"
powershell -Command "Invoke-WebRequest %URL% -OutFile arm-none-eabi-gcc.zip"
powershell -Command "arm-none-eabi-gcc.zip -DestinationPath .\tmp"

del arm-none-eabi-gcc.zip

move tmp\arm-gnu-* .\Heavy

copy resources\heavy-static.a Heavy\lib\heavy-static.a
copy resources\daisy_makefile Heavy\share\daisy_makefile

FOR /F "tokens=* USEBACKQ" %%F IN (`where make`) DO (
SET make_location=%%F
)

copy %make_location% Heavy\bin\make.exe

cd libDaisy
make GCC_PATH=..\Heavy\bin\
cd ..

xcopy /E /H /C /I libDaisy Heavy\lib\libDaisy