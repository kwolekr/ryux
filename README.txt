RY/UX 0.1

=============

A very incomplete x86 operating system written completely in assembly.  It is not currently in a usable state.  RY/UX aims to be a very simple, slim Unix-like OS without strictly adhering to POSIX or other standards.  It is intended to be a real-time OS, using a monolithic kernel design.

The code is written in the NASM flavor of x86 assembly.  Currently, Bochs is used to test and debug RY/UX, for which a bochsrc configuration file is provided for convenience.  As of yet, there seem to be problems entering protected mode on physical hardware.  RY/UX requires an i586 architecture chip or newer to run.

NOTE: This is simply a learning exercise, and not intended to be a serious endeavour in creating an OS!
