# UNPBASIC for DOS

An unprotector/decrypter for "protected" GWBASIC programs.

This is a disassembly of Version 1.10 in released 12/21/1990 by John Thomason. I did not write the original code. I disassembled it, properly labeled things, and added comments. Hopefully it is readable. I hope to eventually release a proper C implementation that is truly portable, so keep an eye on this readme and it will be updated when that's available. If John Thomason finds this and cares to reach out, I would love to hear from you.

# Building the code
This is a program for MSDOS (and clones). It uses only basic DOS calls and thus should work on any DOS or Windows system that allows 16bit code.

It can be built on any system for which the NASM assembler has been implemented. You can download the NASM toolchain from from [nasm.us](https://www.nasm.us) or [build it yourself from source](https://github.com/netwide-assembler/nasm). Or just install it with your system's package manager.

If you have the standard autotools installed, you can simply type ```make``` and it will build a .COM file that you can run in DOS.

If you want to do it manually, ```nasm -fbin -o UNPBASIC.COM UNPBASIC.ASM``` is all you need to do.
