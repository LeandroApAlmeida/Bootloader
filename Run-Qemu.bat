@echo off

echo Executando Qemu...

qemu-system-x86_64 -machine pc -cpu max -drive format=raw,file=bin\bootloader.img