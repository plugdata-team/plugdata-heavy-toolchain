Plugdata Heavy Toolchain
=====

It provides tooling for:

- [hvcc](https://github.com/Wasted-Audio/hvcc)
- [arm-gcc](https://developer.arm.com/downloads/-/gnu-rm) (10-2020-q4)
- [libDaisy](https://github.com/electro-smith/libDaisy)
- [OwlProgram](https://github.com/Wasted-Audio/OwlProgram/)
- [DPF](https://github.com/DISTRHO/DPF) and [DPF-Widgets](https://github.com/DISTRHO/DPF-Widgets)

Windows
-----

Uses a [modified MingW](https://github.com/plugdata-team/plugdata-heavy-toolchain/releases?q=mingw&expanded=true) installation and supports Windows 10 and 11.

macOS
-----

Installation in plugdata triggers xcode for installing standard macOS build tooling. Universal so works for both x86_64 and ARM.

Linux
-----

Uses a stripped down [build-anywhere](https://github.com/theopolis/build-anywhere) toolchain to provide a distro independent compile environment.

Some downsides to this:

- quite old gcc (8.3.0)
- not compatible with ARM
