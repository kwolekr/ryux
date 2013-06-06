nasm src\bootloader\bootloader_I.asm -o obj\bootloader_I.bin
nasm src\bootloader\bootloader_II.asm -o obj\bootloader_II.bin
nasm src\kernel\kernel.asm -o obj\kernel.bin
nasm src\drivers\fdc_driver.asm -o obj\fdc_driver.bin

copy /b obj\bootloader_I.bin + obj\bootloader_II.bin + obj\kernel.bin + obj\fdc_driver.bin ryux.bin
pause
