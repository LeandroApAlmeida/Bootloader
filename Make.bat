@echo off

set NASM_PATH="NASM\nasm.exe"
set OUTPUT_DIR="bin"
set SRC_DIR="src"

if not exist %OUTPUT_DIR% mkdir %OUTPUT_DIR%

del /Q /F bin\*

echo Compilando stage1.asm...

%NASM_PATH% -f bin %SRC_DIR%\stage1.asm -o %OUTPUT_DIR%\stage1.bin

echo.

echo Compilando stage2.asm...

%NASM_PATH% -f bin %SRC_DIR%\stage2.asm -o %OUTPUT_DIR%\stage2.bin

echo.

echo Compilando stage3.asm...

%NASM_PATH% -fbin %SRC_DIR%\stage3.asm -o %OUTPUT_DIR%\stage3.bin

echo.

echo Gerando Bootloader.img...

echo.

copy /b %OUTPUT_DIR%\stage1.bin+%OUTPUT_DIR%\stage2.bin+%OUTPUT_DIR%\stage3.bin %OUTPUT_DIR%\bootloader.img

echo.

pause