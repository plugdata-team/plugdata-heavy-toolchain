Plugdata Heavy Toolchain
=====

It provides tooling for:

- arm-gcc (10-2020-q4)
- libDaisy
- OwlProgram
- DPF and DPF-Widgets

Windows
-----

Uses a modified MingW installation and supports Windows 10 and 11.

macOS
-----

Uses xcode for installing standard macOS build tooling. Universal so works for both x84_64 and ARM.

Linux
-----

Uses a stripped down `build-anywhere` toolchain to provide a distro independent compile environment.

Some downsides to this:

- quite old gcc (8.3.0)
- only compatible with x86_64
