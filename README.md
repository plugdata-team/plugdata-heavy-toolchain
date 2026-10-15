# Heavy toolchain for plugdata

A portable toolchain for compiling Pure Data patches with Heavy, used by plugdata's exporters. It can also be used from the command line.

## Contents

- [hvcc](https://github.com/Wasted-Audio/hvcc), bundled with PyInstaller
- Clang for native builds and ARM GCC (`gcc-arm-none-eabi`) for embedded targets
- Build tools: GNU make and pkgconf; on Windows also a BusyBox `sh` with Unix utilities
- Flashing tools: dfu-util, FirmwareSender
- [libDaisy](https://github.com/electro-smith/libDaisy)
- [DPF](https://github.com/Wasted-Audio/DPF) (patched fork), [DPF-Widgets](https://github.com/DISTRHO/DPF-Widgets) and [PDVG](https://github.com/Wasted-Audio/PDVG)
- [OwlProgram](https://github.com/Wasted-Audio/OwlProgram)
- Linux only: a sysroot with headers and libraries from AlmaLinux 8.9 (glibc, libstdc++, X11, OpenGL, ALSA), so native Linux builds need no system development packages and run on glibc 2.28 or newer

## Supported platforms
- macOS: x86_64 and arm64
- Linux: x86_64 and arm64, with glibc 2.28 or newer
- Windows: x86_64

### Bundled build tools

| Platform | Compilers | Shell and utilities | Make |
| --- | --- | --- | --- |
| macOS | xPack Clang + ARM GCC | System /bin/sh + Unix utilities | Bundled GNU make |
| Linux | xPack Clang + ARM GCC | System /bin/sh + Unix utilities | Bundled GNU make |
| Windows | xPack Clang (MinGW) + ARM GCC | xPack BusyBox-w32 | xPack GNU make |

### Requirements for using the toolchain

- **macOS:** native exports (Pd externals, DPF plugins) need the Xcode Command Line Tools (`xcode-select --install`): the bundled Clang compiles against their macOS SDK.
- **Linux:** the usual coreutils, findutils, grep, sed, awk and diff. No compiler or development packages are needed.
- **Windows:** nothing extra.

## Getting the toolchain

plugdata downloads it from the [releases](https://github.com/plugdata-team/plugdata-heavy-toolchain/releases) and installs it into `~/Documents/plugdata/Toolchain` (Windows: `C:\Users\Public\Documents\plugdata\Toolchain`).

To use it without plugdata, download `heavy-toolchain-<os>-<arch>.tar.xz` for your platform from the same page and extract it. It contains a single `Toolchain/` folder.

## Building the toolchain

Build on the target OS and architecture. You need Git, Python 3.12 or newer, CMake 3.20 or newer, and an internet connection.

```sh
git clone --recursive https://github.com/plugdata-team/plugdata-heavy-toolchain.git
cd plugdata-heavy-toolchain
python3 build.py
```

- **macOS:** install the Xcode Command Line Tools. The toolchain is code signed (hardened runtime) when the `CODESIGN_IDENTITY` in `build.py` is in your keychain; otherwise signing is skipped. CI imports that certificate from the `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64` and `APPLE_DEVELOPER_CERTIFICATE_PASSWORD` secrets.
- **Windows:** install MSYS2 with `make`, and set `MSYS2_ROOT` if it is installed outside `C:/msys64`. Use `python` instead of `python3`.
- **Linux:** build inside the `manylinux_2_28` container, so the toolchain runs on glibc 2.28 and newer. On arm64, use `manylinux_2_28_aarch64`:

  ```sh
  docker run --rm -v "$PWD:/work" -w /work quay.io/pypa/manylinux_2_28_x86_64 sh -ec '
    dnf install -y dnf-plugins-core cpio git alsa-lib-devel python3.12 python3.12-pip
    git config --global --add safe.directory "*"
    /usr/bin/python3.12 build.py'
  ```

  Use `/usr/bin/python3.12`: PyInstaller needs a shared libpython, which the `python3.12` on the container's `PATH` doesn't have.

[build.py](build.py) downloads the pinned dependencies listed in its `MANIFEST`, builds and trims each package step by step, and archives the result. Outputs:

- `.toolchain/Toolchain/`: ready-to-use bundle.
- `.toolchain/dist/heavy-toolchain-<os>-<arch>.tar.xz`: distributable archive (`x64` or `arm64`).

## Testing

After building, run `python3 test.py`, or pass an extracted bundle: `python3 test.py /path/to/Toolchain`.
The test moves the bundle to a path containing spaces while it runs, and moves it back even if a check fails.

- **Built:** native C/C++ with the bundled tools, a Pd external, a DPF plugin with a NanoVG UI, Daisy firmware, and OWL1, OWL2 and OWL3 firmware.
- **Source only:** Unity, Wwise and FMOD (their SDKs aren't bundled), and Pd on Windows (linking needs an external `pd.dll`).
- **Skipped:** WASM, unless you pass `--emsdk /path/to/emsdk`.
- No hardware is flashed.

CI runs this script on every platform, and on Linux again against the extracted archive in a clean container without compilers or development packages.

## Manual usage

The toolchain needs no Python installed. Run the scripts in its `run/` folder with `/bin/sh` (on Windows, the bundled `bin/sh.exe`). For example, after building on macOS:

```sh
/bin/sh \
.toolchain/Toolchain/run/build-cpp.sh \
patch.pd my_patch "Copyright"
```

This generates C/C++ sources in `./my_patch/c/`. On Windows, use forward slashes in paths. Pass `--help` for script options;

## Exporter definitions

plugdata builds its export settings from the JSON files in [resources/exporters](resources/exporters), one per exporter. Each names a script in [resources/run](resources/run), the settings to show (`combo`, `int`, `bool` or `string`), and the argument each setting becomes. A setting with `enabled_if` is only enabled, and only passed to the script, while other settings have the listed values. The scripts turn these arguments into Heavy metadata themselves; `--meta FILE` still overrides that. The full format is described at the top of plugdata's `Source/Heavy/HeavyExporter.h`.

## Updating

Set the toolchain release number in [VERSION](VERSION). Update [COMPATIBILITY](COMPATIBILITY) to map plugdata releases to the toolchain versions they should use.
