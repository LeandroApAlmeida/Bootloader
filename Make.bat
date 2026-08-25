@echo off

chcp 65001 > nul


echo ---------------------------------------------------------------------------------
echo FAKENIX VERSÃO 1.0 (DESENVOLVIDO POR LEANDRO APARECIDO DE ALMEIDA)
echo ---------------------------------------------------------------------------------
echo.


:: ----------------------------------------------------------------------------
:: Seção de constantes
:: ----------------------------------------------------------------------------

set NASM_PATH=nasm.exe

set OUTPUT_DIR=bin

set STAGE1_SOURCE=stage1.asm

set STAGE2_SOURCE=stage2.asm

set STAGE3_SOURCE=stage3.asm

set STAGE1_BINARY=%OUTPUT_DIR%\stage1.bin

set STAGE2_BINARY=%OUTPUT_DIR%\stage2.bin

set STAGE3_BINARY=%OUTPUT_DIR%\stage3.bin

set IMAGE=%OUTPUT_DIR%\bootloader.img


:: ----------------------------------------------------------------------------
:: Criação do diretório de destino dos arquivos binários
:: ----------------------------------------------------------------------------

if not exist %OUTPUT_DIR% mkdir %OUTPUT_DIR%

del /Q /F bin\*


:: ----------------------------------------------------------------------------
:: Montagem de "stage1.asm" com o montador NASM
:: ----------------------------------------------------------------------------

echo Montando stage1.asm...

%NASM_PATH% -f bin %STAGE1_SOURCE% -o %STAGE1_BINARY%

if %errorlevel% neq 0 echo Erro ao gerar %STAGE1_BINARY% && pause && exit

echo.


:: ----------------------------------------------------------------------------
:: Montagem de "stage2.asm" com o montador NASM
:: ----------------------------------------------------------------------------

echo Montando stage2.asm...

%NASM_PATH% -f bin %STAGE2_SOURCE% -o %STAGE2_BINARY%

if %errorlevel% neq 0 echo Erro ao gerar %STAGE2_BINARY% && pause && exit

echo.


:: ----------------------------------------------------------------------------
:: Montagem de "stage3.asm" com o montador NASM
:: ----------------------------------------------------------------------------

echo Montando stage3.asm...

%NASM_PATH% -f bin %STAGE3_SOURCE% -o %STAGE3_BINARY%

if %errorlevel% neq 0 echo Erro ao gerar %STAGE3_BINARY% && pause && exit

echo.


:: ----------------------------------------------------------------------------
:: Criação da imagem de disco em RAW FORMAT
:: ----------------------------------------------------------------------------

echo Gerando bootloader.img...

echo.

copy /b %STAGE1_BINARY%+%STAGE2_BINARY%+%STAGE3_BINARY% %IMAGE%


echo.


pause