git clone --recursive https://github.com/electro-smith/DaisyToolchain

move DaisyToolchain/windows Heavy
copy resources\heavy-static.a Heavy\lib\heavy-static.a
copy resources\daisy_makefile Heavy\share\daisy_makefile

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
Heavy\bin\make GCC_PATH=../Heavy/bin
cd ..

xcopy /E /H /C /I libDaisy Heavy\lib\libDaisy
