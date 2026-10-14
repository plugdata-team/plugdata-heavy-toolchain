#!/usr/bin/env python3
"""Build the portable Heavy toolchain for the current host.

Run on the target OS/architecture with Python 3.12+, CMake 3.20+ and Git
(Linux: inside the manylinux_2_28 container, Windows: with MSYS2 make installed).
Result: .toolchain/Toolchain and .toolchain/dist/heavy-toolchain-<os>-<arch>.tar.xz
"""
import hashlib
import os
import platform
import shutil
import subprocess
import sys
import sysconfig
import tarfile
import tomllib
import urllib.request
import venv
import zipfile
from pathlib import Path

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

MANIFEST = [
    # package           platform          url                                                                                                                                              sha256
    ("clang",           "macos-x86_64",   "https://github.com/xpack-dev-tools/clang-xpack/releases/download/v21.1.8-1/xpack-clang-21.1.8-1-darwin-x64.tar.gz",                           "eab22258684105f5c32bb29772e2b17bc2ec4eac49b3c4d1775e45b3d1baf385"),
    ("clang",           "macos-arm64",    "https://github.com/xpack-dev-tools/clang-xpack/releases/download/v21.1.8-1/xpack-clang-21.1.8-1-darwin-arm64.tar.gz",                         "562270fc3029fbec56cadde80223efe2ea33e9fde46954582447afb4832310ea"),
    ("clang",           "linux-x86_64",   "https://github.com/xpack-dev-tools/clang-xpack/releases/download/v21.1.8-1/xpack-clang-21.1.8-1-linux-x64.tar.gz",                            "0db58136aedb58b9af8c605a1b1570defbe06618f82bff60d24d3327f81d8321"),
    ("clang",           "linux-arm64",    "https://github.com/xpack-dev-tools/clang-xpack/releases/download/v21.1.8-1/xpack-clang-21.1.8-1-linux-arm64.tar.gz",                          "be1eae2706c049ff9d1c5816e58bb5557d75810c9762cb929208472f7914617e"),
    ("clang",           "windows-x86_64", "https://github.com/xpack-dev-tools/clang-xpack/releases/download/v21.1.8-1/xpack-clang-21.1.8-1-win32-x64.zip",                               "b23d38e2c1c539182919e147e7158fd8b4e8bdd9e6ddc5dfe06f6488c6d9d516"),
    ("arm-gcc",         "macos-x86_64",   "https://github.com/xpack-dev-tools/arm-none-eabi-gcc-xpack/releases/download/v15.2.1-1.1/xpack-arm-none-eabi-gcc-15.2.1-1.1-darwin-x64.tar.gz",   "5be906a5194c3173e145a58048e5607ffff947773237802b93e55e23c415f1b6"),
    ("arm-gcc",         "macos-arm64",    "https://github.com/xpack-dev-tools/arm-none-eabi-gcc-xpack/releases/download/v15.2.1-1.1/xpack-arm-none-eabi-gcc-15.2.1-1.1-darwin-arm64.tar.gz", "574082d35e49a2bcbdc355836b2a3ae5e5bb3b9456c9f5e37177db2ab4aad870"),
    ("arm-gcc",         "linux-x86_64",   "https://github.com/xpack-dev-tools/arm-none-eabi-gcc-xpack/releases/download/v15.2.1-1.1/xpack-arm-none-eabi-gcc-15.2.1-1.1-linux-x64.tar.gz",    "da6a49ad4003944b823c6c93702a8787c922ab34bd7e918ec0eaf6933a9b1ff6"),
    ("arm-gcc",         "linux-arm64",    "https://github.com/xpack-dev-tools/arm-none-eabi-gcc-xpack/releases/download/v15.2.1-1.1/xpack-arm-none-eabi-gcc-15.2.1-1.1-linux-arm64.tar.gz",  "67980c7990eba7bb7ffdf39699102effd70889f5ac427be19a8c8a6c5fab2972"),
    ("arm-gcc",         "windows-x86_64", "https://github.com/xpack-dev-tools/arm-none-eabi-gcc-xpack/releases/download/v15.2.1-1.1/xpack-arm-none-eabi-gcc-15.2.1-1.1-win32-x64.zip",       "bae6a3d1667697ce750c3b13d6d26d80973ecedc2cc87bf04869e83447fd93ea"),
    ("windows-tools",   "windows-x86_64", "https://github.com/xpack-dev-tools/windows-build-tools-xpack/releases/download/v4.4.1-3/xpack-windows-build-tools-4.4.1-3-win32-x64.zip",     "113d4dfdbbc56dc9b865c9f75d38cd0da82f0d7094187e6f7a803fe6eef1d218"),
    ("make",            "all",            "https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz",                                                                                                "dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3"),
    ("dfu-util",        "all",            "https://dfu-util.sourceforge.net/releases/dfu-util-0.11.tar.gz",                                                                                "b4b53ba21a82ef7e3d4c47df2952adf5fa494f499b6b0b57c58c5d04ae8ff19e"),
    ("libusb",          "all",            "https://github.com/libusb/libusb/releases/download/v1.0.30/libusb-1.0.30.tar.bz2",                                                              "fea36f34f9156400209595e300840767ab1a385ede1dc7ee893015aea9c6dbaf"),
    ("pkgconf",         "all",            "https://distfiles.ariadne.space/pkgconf/pkgconf-2.3.0.tar.xz",                                                                                  "3a9080ac51d03615e7c1910a0a2a8df08424892b5f13b0628a204d3fcce0ea8b"),
    ("firmware-sender", "all",            "https://api.github.com/repos/Wasted-Audio/FirmwareSender_plugdata/tarball/14942603641c4205d9ea3236ab74c330dbf3f33a",                            "33a00b5f4e811fb92bbc445ee744c6812d42a31bbc2ca494f0687673fe0e0e5f"),
    ("juce",            "all",            "https://github.com/juce-framework/JUCE/archive/refs/tags/7.0.12.tar.gz",                                                                        "94e3b35e1990cd67f59736bb5e1eff1cfd9590b16fea82696f309a8f59452434"),
]

# Tools used to freeze hvcc. hvcc's own dependencies come from submodules/hvcc/poetry.lock.
PYINSTALLER = [
    "pyinstaller==6.22.0",
    "pyinstaller-hooks-contrib==2026.8",
    "altgraph==0.17.5",
    "packaging==26.0",
    "setuptools==80.10.2",
    "macholib==1.16.4; sys_platform == 'darwin'",
    "pefile==2024.8.26; sys_platform == 'win32'",
    "pywin32-ctypes==0.2.3; sys_platform == 'win32'",
]

# Linux only: development files from signed AlmaLinux 8.9 RPMs, so exports link against glibc 2.28.
SYSROOT_URL = "https://vault.almalinux.org/8.9"
SYSROOT_REPOSITORIES = ["BaseOS", "AppStream", "PowerTools"]
SYSROOT_PACKAGES = [
    "gcc", "libgcc", "libstdc++", "libstdc++-devel", "libstdc++-static", "libatomic",
    "glibc", "glibc-devel", "glibc-headers", "kernel-headers", "alsa-lib", "alsa-lib-devel",
    "libX11", "libX11-devel", "libX11-xcb", "libXau", "libXau-devel", "libxcb", "libxcb-devel",
    "libXext", "libXext-devel", "libXcursor", "libXcursor-devel", "libXrender", "libXrender-devel",
    "libXfixes", "libXfixes-devel", "libXrandr", "libXrandr-devel", "libXinerama", "libXinerama-devel",
    "libXi", "libXi-devel", "xorg-x11-proto-devel", "mesa-libGL-devel", "mesa-libglapi",
    "libglvnd", "libglvnd-devel", "libglvnd-glx", "libglvnd-opengl", "libglvnd-gles", "libglvnd-egl",
]

# macOS only: the toolchain is code signed when this identity is in the keychain (CI imports it from secrets).
CODESIGN_IDENTITY = "Developer ID Application: Timothy Schoen (7SV7JPRR2L)"

# ---------------------------------------------------------------------------
# Paths and host
# ---------------------------------------------------------------------------

REPO = Path(__file__).resolve().parent
RESOURCES = REPO / "resources"
DOWNLOADS = REPO / ".toolchain/downloads"
BUILD = REPO / ".toolchain/build"
OUTPUT = REPO / ".toolchain/Toolchain"
DIST = REPO / ".toolchain/dist"

_arch = {"x86_64": "x86_64", "amd64": "x86_64", "arm64": "arm64", "aarch64": "arm64"}[platform.machine().lower()]
HOST = {"Darwin": "macos", "Linux": "linux", "Windows": "windows"}[platform.system()] + "-" + _arch
MACOS, LINUX, WINDOWS = HOST.startswith("macos"), HOST.startswith("linux"), HOST.startswith("windows")
EXE = ".exe" if WINDOWS else ""
JOBS = os.environ.get("TOOLCHAIN_JOBS", str(os.cpu_count()))

CLANG_BIN = OUTPUT / "packages/clang/bin"
ARM_GCC_BIN = OUTPUT / "packages/arm-gcc/bin"
WINDOWS_TOOLS_BIN = OUTPUT / "packages/windows-tools/bin"
NATIVE = BUILD / "native"  # install prefix for host tools that are only partially shipped
MSYS = Path(os.environ.get("MSYS2_ROOT", "C:/msys64"))

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def executeCommand(*args, cwd=None, env=None):
    args = [str(arg) for arg in args]
    print("> " + subprocess.list2cmdline(args), flush=True)
    subprocess.run(args, cwd=cwd, env=env, check=True)


def commandOutput(*args, cwd=None, env=None):
    return subprocess.check_output([str(arg) for arg in args], cwd=cwd, env=env, text=True).strip()


def copyFile(source, destination):
    Path(destination).parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def copyDirectory(source, destination):
    shutil.copytree(source, destination, symlinks=True, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns(".git", "__pycache__", "*.pyc", ".DS_Store"))


def deleteFile(path):
    path = Path(path)
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    elif path.exists() or path.is_symlink():
        path.unlink()


def deleteMatching(root, *patterns):
    for pattern in patterns:
        for path in list(Path(root).glob(pattern)):
            deleteFile(path)


def patchFile(path, old, new):
    text = path.read_text()
    if old not in text:
        raise RuntimeError(f"Patch no longer applies to {path}: {old!r}")
    path.write_text(text.replace(old, new))


def copyLicenses(source, name):
    for path in Path(source).iterdir():
        if path.is_file() and path.name.upper().startswith(("COPYING", "LICENSE")):
            copyFile(path, OUTPUT / "licenses" / name / path.name)


def posixPath(path):
    """Path as seen by MSYS2 tools on Windows; unchanged elsewhere."""
    return commandOutput(MSYS / "usr/bin/cygpath.exe", "-u", path) if WINDOWS else str(path)


def sha256(path):
    with open(path, "rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def download(name):
    url, checksum = next((url, sha) for package, host, url, sha in MANIFEST if package == name and host in (HOST, "all"))
    path = DOWNLOADS / url.rsplit("/", 1)[1]
    if not path.exists() or sha256(path) != checksum:
        print(f"Downloading {url}", flush=True)
        DOWNLOADS.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(url, headers={"User-Agent": "plugdata-heavy-toolchain"})
        with urllib.request.urlopen(request, timeout=60) as response, path.open("wb") as file:
            shutil.copyfileobj(response, file)
        if sha256(path) != checksum:
            raise RuntimeError(f"Checksum mismatch for {url}")
    return path


def unpack(name):
    """Download and extract a manifest package; returns the archive's top-level directory."""
    archive, destination = download(name), BUILD / "sources" / name
    deleteFile(destination)
    destination.mkdir(parents=True)
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as bundle:
            for member in bundle.infolist():
                path = Path(bundle.extract(member, destination))
                if (member.external_attr >> 16) & 0o111:
                    path.chmod(0o755)
    else:
        with tarfile.open(archive) as bundle:
            bundle.extractall(destination, filter="data")
    [root] = destination.iterdir()
    return root


def nativeEnvironment():
    """Environment for building host tools (pkgconf, libusb, dfu-util, make)."""
    env = os.environ.copy()
    env.pop("SHELL", None)
    env.pop("MAKESHELL", None)
    if MACOS:
        env |= {"CC": "/usr/bin/clang", "CXX": "/usr/bin/clang++", "MACOSX_DEPLOYMENT_TARGET": "11.0",
                "SDKROOT": commandOutput("xcrun", "--sdk", "macosx", "--show-sdk-path")}
    elif LINUX:
        env |= {"CC": "gcc", "CXX": "g++"}  # the manylinux container's compiler, for glibc 2.28 binaries
    else:
        env |= {"CC": "clang", "CXX": "clang++", "AR": "llvm-ar", "RANLIB": "llvm-ranlib",
                "PATH": os.pathsep.join([str(CLANG_BIN), str(MSYS / "usr/bin"), env["PATH"]])}
        env.pop("MSYS2_ARG_CONV_EXCL", None)
        env.pop("MSYS_NO_PATHCONV", None)
    return env


def configureAndMake(source, *options, env):
    """Build an autoconf release tarball and install it into NATIVE."""
    build = BUILD / (source.name + "-build")
    build.mkdir(parents=True)
    shell = MSYS / "usr/bin/bash.exe" if WINDOWS else "/bin/sh"
    make = MSYS / "usr/bin/make.exe" if WINDOWS else OUTPUT / "bin/make"
    host = ["--host=x86_64-w64-mingw32"] if WINDOWS else []
    executeCommand(shell, posixPath(source / "configure"), "--prefix=" + posixPath(NATIVE), *host, *options, cwd=build, env=env)
    executeCommand(make, "-j" + JOBS, cwd=build, env=env)
    executeCommand(make, "install", cwd=build, env=env)


def targetEnvironment():
    """Environment for building ARM firmware libraries with the bundled tools."""
    tools = WINDOWS_TOOLS_BIN if WINDOWS else OUTPUT / "bin"
    env = os.environ | {"PATH": os.pathsep.join([str(tools), str(ARM_GCC_BIN), str(OUTPUT / "bin"), os.environ["PATH"]])}
    if WINDOWS:
        env["SHELL"] = env["MAKESHELL"] = str(WINDOWS_TOOLS_BIN / "sh.exe")
    return env, tools / ("make" + EXE)

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------

def prepare():
    if sys.version_info < (3, 12):
        sys.exit("Python 3.12 or newer is required")
    if LINUX and tuple(map(int, os.confstr("CS_GNU_LIBC_VERSION").split()[-1].split("."))) > (2, 28):
        sys.exit("Build Linux toolchains in the manylinux_2_28 container (host glibc is too new)")
    if LINUX and not sysconfig.get_config_var("Py_ENABLE_SHARED"):
        sys.exit("PyInstaller needs a Python with a shared libpython; in manylinux, run /usr/bin/python3.12 build.py")
    if any(submodule.is_dir() and not any(submodule.iterdir()) for submodule in (REPO / "submodules").iterdir()):
        sys.exit("Submodules are missing; run: git submodule update --init --recursive")
    deleteFile(BUILD)
    deleteFile(OUTPUT)
    (OUTPUT / "bin").mkdir(parents=True)


def packageXpack(name):
    destination = OUTPUT / "packages" / name
    shutil.move(unpack(name), destination)
    deleteMatching(destination, "bin/*gdb*", "bin/*gcov*", "bin/*gprof*", "bin/*lto-dump*", "bin/*gfortran*",
                   "bin/python*", "bin/libpython*", "lib/python*", "lib/libpython*", "libexec/python*", "libexec/libpython*",
                   "lib/gcc/*/*/f951*", "lib/gcc/*/*/cc1obj*", "libexec/gcc/*/*/f951*", "libexec/gcc/*/*/cc1obj*",
                   "lib/libcc1*", "share/doc", "share/info", "share/man")


def packageClang():
    packageXpack("clang")
    keep = {"clang", "clang++", "clang-21", "ld.lld", "ld64.lld", "lld", "lld-link", "llvm-ar", "llvm-ranlib",
            "llvm-strip", "llvm-nm", "llvm-objcopy", "llvm-readelf", "llvm-readobj", "llvm-size",
            "clang-target-wrapper", "llvm-windres", "llvm-rc", "llvm-dlltool"}  # last four: Windows wrappers
    keep |= {path.resolve().name for path in CLANG_BIN.iterdir() if path.name in keep}  # symlink targets, e.g. clang-21
    for path in CLANG_BIN.iterdir():
        if path.name.removesuffix(".exe") not in keep and path.suffix.lower() != ".dll":
            deleteFile(path)
    deleteMatching(OUTPUT / "packages/clang", "include/llvm", "include/clang", "lib/cmake", "lib/libLLVM*.a", "lib/libclang*.a")


def packageArmGcc():
    packageXpack("arm-gcc")
    root = OUTPUT / "packages/arm-gcc"
    deleteMatching(root, "arm-none-eabi/share", "arm-none-eabi/lib/arm")
    # Daisy and OWL only use Cortex-M4F/M7 hard-float multilibs.
    for thumb in [root / "arm-none-eabi/lib/thumb", *root.glob("lib/gcc/arm-none-eabi/*/thumb")]:
        for path in thumb.iterdir():
            deleteFile(path / "softfp" if path.name in ("v7e-m+dp", "v7e-m+fp") else path)


def packageWindowsTools():
    packageXpack("windows-tools")
    busybox = WINDOWS_TOOLS_BIN / "busybox.exe"
    for applet in commandOutput(busybox, "--list").split():
        target = WINDOWS_TOOLS_BIN / (applet + ".exe")
        if not target.exists():
            try:
                os.link(busybox, target)  # hard links need no developer mode
            except OSError:
                copyFile(busybox, target)
    copyFile(WINDOWS_TOOLS_BIN / "sh.exe", OUTPUT / "bin/sh.exe")


def packageMake():
    source = unpack("make")
    env = nativeEnvironment()
    executeCommand("/bin/sh", "configure", "--prefix=/", "--disable-nls", "--without-guile", cwd=source, env=env)
    executeCommand("/bin/sh", "build.sh", cwd=source, env=env)  # bootstraps without an existing make
    copyFile(source / "make", OUTPUT / "bin/make")
    copyLicenses(source, "make")


def packagePkgconf():
    source = unpack("pkgconf")
    configureAndMake(source, "--disable-shared", "--enable-static", "CPPFLAGS=-DPKGCONFIG_IS_STATIC",
                     "--with-pkg-config-dir=", "--with-personality-dir=",
                     "--with-system-libdir=/usr/lib", "--with-system-includedir=/usr/include", env=nativeEnvironment())
    copyFile(NATIVE / f"bin/pkgconf{EXE}", OUTPUT / f"bin/pkgconf{EXE}")
    copyFile(NATIVE / f"bin/pkgconf{EXE}", OUTPUT / f"bin/pkg-config{EXE}")
    copyLicenses(source, "pkgconf")


def packageDFU():
    libusb, dfu = unpack("libusb"), unpack("dfu-util")
    env = nativeEnvironment()
    configureAndMake(libusb, "--disable-shared", "--enable-static", *(["--disable-udev"] if LINUX else []), env=env)
    # Link dfu-util against the static libusb we just built.
    pkgconf = NATIVE / f"bin/pkgconf{EXE}"
    pkgconf_env = env | {"PKG_CONFIG_LIBDIR": str(NATIVE / "lib/pkgconfig"), "PKG_CONFIG_PATH": ""}
    env |= {"USB_CFLAGS": commandOutput(pkgconf, "--cflags", "libusb-1.0", env=pkgconf_env),
            "USB_LIBS": commandOutput(pkgconf, "--static", "--libs", "libusb-1.0", env=pkgconf_env)}
    configureAndMake(dfu, "--disable-shared", env=env)
    for name in ("dfu-util", "dfu-prefix", "dfu-suffix"):
        copyFile(NATIVE / f"bin/{name}{EXE}", OUTPUT / f"bin/{name}{EXE}")
    copyLicenses(libusb, "libusb")
    copyLicenses(dfu, "dfu-util")


def packageFirmwareSender():
    firmware, juce = unpack("firmware-sender"), unpack("juce")
    env = nativeEnvironment()
    if WINDOWS:
        cc, cxx = CLANG_BIN / "clang.exe", CLANG_BIN / "clang++.exe"
        make, generator = WINDOWS_TOOLS_BIN / "make.exe", "MinGW Makefiles"
        # CMake's MinGW generator must not find any sh.exe (MSYS, Git) on PATH.
        env["PATH"] = os.pathsep.join(p for p in os.environ["PATH"].split(os.pathsep) if not (Path(p) / "sh.exe").is_file())
        env["SHELL"] = env["MAKESHELL"] = "cmd.exe"
    else:
        cc, cxx = env["CC"], env["CXX"]
        make, generator = OUTPUT / "bin/make", "Unix Makefiles"
    build = BUILD / "firmware-sender-build"
    executeCommand("cmake", "-S", RESOURCES / "FirmwareSender", "-B", build, "-G", generator, "-DCMAKE_BUILD_TYPE=Release",
                   f"-DCMAKE_C_COMPILER={Path(cc).as_posix()}", f"-DCMAKE_CXX_COMPILER={Path(cxx).as_posix()}",
                   f"-DCMAKE_MAKE_PROGRAM={make.as_posix()}", f"-DCMAKE_INSTALL_PREFIX={OUTPUT.as_posix()}",
                   f"-DFIRMWARE_SOURCE={firmware.as_posix()}", f"-DJUCE_SOURCE={juce.as_posix()}",
                   *(["-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0"] if MACOS else []), env=env)
    executeCommand("cmake", "--build", build, "--parallel", JOBS, env=env)
    executeCommand("cmake", "--install", build, env=env)
    if LINUX:
        # ALSA is FirmwareSender's only extra runtime dependency; found via its $ORIGIN/../lib RPATH.
        libasound = Path(commandOutput("gcc", "-print-file-name=libasound.so.2"))
        if not libasound.is_absolute():
            sys.exit("ALSA library not found; install alsa-lib-devel")
        copyFile(libasound.resolve(), OUTPUT / "lib/libasound.so.2")
        copyDirectory("/usr/share/licenses/alsa-lib", OUTPUT / "licenses/alsa-lib")
    copyLicenses(firmware, "firmware")
    copyLicenses(juce, "juce")


def sysrootPath(path):
    """Where an RPM file belongs in the sysroot, or None if exporters don't need it."""
    if path.parts[0] in ("lib", "lib64"):
        path = "usr" / path
    name = path.name
    if path.is_relative_to("usr/include"):
        return path
    if path.is_relative_to("usr/lib/gcc"):
        # Native C/C++ runtime only: no 32-bit multilibs, sanitizers or OpenMP.
        if "32" in path.parts or "x32" in path.parts:
            return None
        runtime = name.startswith(("libgcc", "libstdc++", "libsupc++", "libatomic")) and (name.endswith(".a") or ".so" in name)
        return path if {"include", "include-fixed"} & set(path.parts) or name.endswith(".o") or runtime else None
    if path.parent in (Path("usr/lib"), Path("usr/lib64")) and (".so" in name or name.endswith((".o", ".a"))):
        return path
    if path.parent in (Path("usr/lib64/pkgconfig"), Path("usr/share/pkgconfig")) and name.endswith(".pc"):
        return path
    return None


def packageLinuxSysroot():
    arch = "x86_64" if HOST == "linux-x86_64" else "aarch64"
    triple = f"{arch}-redhat-linux"
    key = "/etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux"
    root, licenses = OUTPUT / "sysroot", OUTPUT / "licenses/linux-sysroot"
    repos, rpms, rpmdb, unpacked = (BUILD / f"sysroot-{name}" for name in ("repos", "rpms", "rpmdb", "unpacked"))
    for directory in (repos, rpms, rpmdb, licenses, root / "usr/lib", root / "usr/lib64"):
        directory.mkdir(parents=True)
    (root / "lib").symlink_to("usr/lib")
    (root / "lib64").symlink_to("usr/lib64")

    # Download the explicit package list without dependency resolution, and verify signatures.
    (repos / "sysroot.repo").write_text("".join(
        f"[{repo}]\nname={repo}\nbaseurl={SYSROOT_URL}/{repo}/{arch}/os/\ngpgcheck=1\ngpgkey=file://{key}\n\n"
        for repo in SYSROOT_REPOSITORIES))
    executeCommand("dnf", "-y", "--releasever=8.9", f"--setopt=reposdir={repos}", "--setopt=module_platform_id=platform:el8",
                   "download", f"--archlist={arch},noarch", f"--destdir={rpms}", *SYSROOT_PACKAGES)
    executeCommand("rpmkeys", "--dbpath", rpmdb, "--import", key)

    # Extract only headers, libraries and licenses; never run RPM install scripts.
    inventory = []
    for rpm in sorted(rpms.glob("*.rpm")):
        executeCommand("rpmkeys", "--dbpath", rpmdb, "--checksig", rpm)
        inventory.append(commandOutput("rpm", "-qp", "--qf", "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\t%{SOURCERPM}\t%{LICENSE}", rpm))
        deleteFile(unpacked)
        unpacked.mkdir()
        executeCommand("sh", "-c", 'rpm2cpio "$1" | cpio -idm --quiet --no-absolute-filenames', "sh", rpm, cwd=unpacked)
        for path in unpacked.rglob("*"):
            if path.is_dir() and not path.is_symlink():
                continue
            relative = path.relative_to(unpacked)
            if sysrootPath(relative):
                target = root / sysrootPath(relative)
            elif relative.is_relative_to("usr/share/licenses") or (relative.is_relative_to("usr/share/doc") and
                    path.name.upper().startswith(("COPYING", "LICENSE", "COPYRIGHT", "NOTICE", "AUTHORS"))):
                target = licenses / relative.relative_to("usr/share")
            else:
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            deleteFile(target)
            shutil.copy2(path, target, follow_symlinks=False)
    (licenses / "packages.tsv").write_text("\n".join(sorted(inventory)) + "\n")

    # Absolute RPM symlinks must point inside the sysroot, never at the host.
    for path in root.rglob("*"):
        if path.is_symlink() and path.readlink().is_absolute():
            target = root / str(path.readlink()).lstrip("/")
            path.unlink()
            path.symlink_to(os.path.relpath(target, path.parent))
    for path in root.rglob("*"):
        if path.is_symlink() and (not path.exists() or not path.resolve().is_relative_to(root.resolve())):
            raise RuntimeError(f"Broken sysroot symlink: {path} -> {path.readlink()}")

    # bin/clang and bin/clang++ wrap the bundled Clang with this sysroot.
    [crtbegin] = (root / "usr/lib/gcc").glob(f"{triple}/*/crtbegin.o")
    config = (f"--target={triple}\n--sysroot=<CFGDIR>\n--gcc-install-dir=<CFGDIR>/{crtbegin.parent.relative_to(root).as_posix()}\n"
              "--ld-path=<CFGDIR>/../packages/clang/bin/ld.lld\n--rtlib=libgcc\n--unwindlib=libgcc\n")
    for name in ("clang", "clang++"):
        # Static libstdc++ avoids imposing the sysroot's C++ runtime on users.
        (root / f"{name}.cfg").write_text(config + ("-stdlib=libstdc++\n-static-libstdc++\n" if name == "clang++" else ""))
        wrapper = OUTPUT / "bin" / name
        wrapper.write_text('#!/bin/sh\nroot=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)\n'
                           "unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH GCC_EXEC_PREFIX COMPILER_PATH\n"
                           f'exec "$root/packages/clang/bin/{name}" --no-default-config --config="$root/sysroot/{name}.cfg" "$@"\n')
        wrapper.chmod(0o755)


def packageDPF():
    for name, submodule in (("DPF", "dpf"), ("dpf-widgets", "dpf-widgets"), ("pdvg", "pdvg")):
        copyDirectory(REPO / "submodules" / submodule, OUTPUT / "lib" / name)
    # This DPF revision passes the GCC-only -posix flag to Clang on Windows.
    patchFile(OUTPUT / "lib/DPF/Makefile.base.mk",
              "BASE_FLAGS += -posix -D__STDC_FORMAT_MACROS=1 -D__USE_MINGW_ANSI_STDIO=1",
              "ifeq ($(GCC),true)\nBASE_FLAGS += -posix\nendif\nBASE_FLAGS += -D__STDC_FORMAT_MACROS=1 -D__USE_MINGW_ANSI_STDIO=1")


def packageLibDaisy():
    libdaisy = OUTPUT / "lib/libdaisy"
    copyDirectory(REPO / "submodules/libdaisy", libdaisy)
    env, make = targetEnvironment()
    executeCommand(make, "-j" + JOBS, "GCC_PATH=" + ARM_GCC_BIN.as_posix(), cwd=libdaisy, env=env)
    deleteMatching(libdaisy, "**/*.o", "**/*.d", "**/*.dep")
    # Exports only need the CMSIS headers.
    for path in [*(libdaisy / "Drivers/CMSIS-DSP").iterdir(), *(libdaisy / "Drivers/CMSIS_5/CMSIS").iterdir()]:
        if path.name not in ("Include", "PrivateInclude", "Core") and not path.name.upper().startswith(("LICENSE", "COPYING")):
            deleteFile(path)


def packageOwlProgram():
    owl = OUTPUT / "lib/OwlProgram"
    copyDirectory(REPO / "submodules/OwlProgram", owl)
    # OWL1/2 and OWL3 have different CPUs, so keep a library directory per PLATFORM.
    compile_mk = owl / "compile.mk"
    compile_mk.write_text("OWL_LIBRARY_DIR = Libraries/$(PLATFORM)\n" + compile_mk.read_text())
    patchFile(compile_mk, "Libraries/libowlprg.a", "$(OWL_LIBRARY_DIR)/libowlprg.a")
    patchFile(compile_mk, "Libraries/libdaisysp.a", "$(OWL_LIBRARY_DIR)/libdaisysp.a")
    # GCC 15 rejects <cmath>/<algorithm> in freestanding mode; OWL still links -nostdlib.
    patchFile(compile_mk, "CXXFLAGS += -std=gnu++17", "CXXFLAGS += -std=gnu++17 -fno-freestanding")
    env, make = targetEnvironment()
    for board in ("OWL1", "OWL2", "OWL3"):
        (owl / "Libraries" / board).mkdir(parents=True, exist_ok=True)
        executeCommand(make, "-j" + JOBS, "libs", "PLATFORM=" + board, "BUILD=Build/" + board,
                       "TOOLROOT=" + ARM_GCC_BIN.as_posix() + "/", cwd=owl, env=env)
    deleteMatching(owl, "**/*.o", "**/*.d", "**/*.dep")
    # OwlProgram gets copied into export folders, so it carries its own FirmwareSender.
    copyFile(OUTPUT / f"bin/FirmwareSender{EXE}", owl / f"Tools/FirmwareSender{EXE}")
    if LINUX:
        copyFile(OUTPUT / "lib/libasound.so.2", owl / "lib/libasound.so.2")
        copyDirectory(OUTPUT / "licenses/alsa-lib", owl / "Tools/licenses/alsa-lib")
    copyDirectory(OUTPUT / "licenses/firmware", owl / "Tools/licenses/firmware")
    copyDirectory(OUTPUT / "licenses/juce", owl / "Tools/licenses/juce")


def packageHvcc():
    source, licenses = REPO / "submodules/hvcc", OUTPUT / "licenses/hvcc"
    environment = BUILD / "hvcc-venv"
    python = environment / ("Scripts/python.exe" if WINDOWS else "bin/python")
    venv.create(environment, with_pip=True, clear=True)

    # Install hvcc's locked runtime dependencies (Poetry "main" group, hash-checked), then PyInstaller.
    requirements = []
    for package in tomllib.loads((source / "poetry.lock").read_text())["package"]:
        if "main" in package["groups"]:
            marker = package.get("markers", "")
            marker = marker.get("main", "") if isinstance(marker, dict) else marker
            requirements.append(f"{package['name']}=={package['version']}" + (f" ; {marker}" if marker else "")
                                + "".join(f" --hash={file['hash']}" for file in package["files"]))
    requirements_file = BUILD / "hvcc-requirements.txt"
    requirements_file.write_text("\n".join(requirements) + "\n")
    executeCommand(python, "-m", "pip", "install", "--only-binary=:all:", "--no-deps", "--require-hashes", "-r", requirements_file)
    executeCommand(python, "-m", "pip", "install", "--only-binary=:all:", "--no-deps", *PYINSTALLER)
    executeCommand(python, "-m", "pip", "check")

    executeCommand(python, "-m", "PyInstaller", "--noconfirm", "--clean", "--onedir", "--noupx", "--name", "Heavy",
                   "--distpath", OUTPUT / "bin", "--workpath", BUILD / "pyinstaller", "--specpath", BUILD, "--paths", source,
                   "--collect-all", "arpeggio", "--collect-all", "pydantic_extra_types", "--collect-submodules", "hvcc.generators",
                   *[arg for folder in ("generators", "core", "interpreters") for arg in ("--add-data", f"{source / 'hvcc' / folder}:hvcc/{folder}")],
                   source / "hvcc/main.py", env=os.environ | {"PYINSTALLER_CONFIG_DIR": str(BUILD / "pyinstaller-config")})
    for pointer in (OUTPUT / "bin/Heavy/_internal/hvcc").rglob(".git"):
        deleteFile(pointer)  # submodule pointers inside generator resources

    # Licenses of hvcc, Python and every package frozen into Heavy.
    copyFile(source / "LICENSE", licenses / "LICENSE")
    copyFile(source / "poetry.lock", licenses / "poetry.lock")
    copyFile(requirements_file, licenses / "runtime-requirements.txt")
    for python_license in (Path(sys.base_prefix) / "LICENSE.txt", Path(sysconfig.get_path("stdlib")) / "LICENSE.txt"):
        if python_license.is_file():
            copyFile(python_license, licenses / "PYTHON-LICENSE.txt")
            break
    [site_packages] = environment.glob("**/site-packages")
    for info in site_packages.glob("*.dist-info"):
        for path in info.rglob("*"):
            if path.is_file() and any(word in path.name.lower() for word in ("license", "copying", "copyright")):
                copyFile(path, licenses / info.name.split("-")[0] / path.relative_to(info))


def packageResources():
    copyDirectory(RESOURCES / "run", OUTPUT / "run")  # generator scripts
    copyDirectory(RESOURCES / "etc", OUTPUT / "etc")  # Daisy board files and linker scripts
    copyFile(REPO / "VERSION", OUTPUT / "VERSION")
    # Daisy DFU access without admin rights: a udev rule on Linux, a USB driver on Windows.
    if LINUX:
        copyDirectory(RESOURCES / "linux", OUTPUT / "run")
    if WINDOWS:
        copyDirectory(RESOURCES / "windows", OUTPUT / "etc")


def codesignMacOS():
    if CODESIGN_IDENTITY not in commandOutput("security", "find-identity", "-v", "-p", "codesigning"):
        print(f"Skipping code signing: {CODESIGN_IDENTITY} is not in the keychain", flush=True)
        return
    # Hardened runtime, with library validation disabled (as in the original toolchain build).
    entitlements = BUILD / "entitlements.plist"
    entitlements.write_text('<?xml version="1.0" encoding="UTF-8"?>\n'
                            '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
                            '<plist version="1.0"><dict>\n'
                            '    <key>com.apple.security.cs.disable-library-validation</key><true/>\n'
                            '</dict></plist>\n')
    # Every Mach-O executable and library: 64-bit, 32-bit or universal.
    for path in OUTPUT.rglob("*"):
        if path.is_file() and not path.is_symlink() and (os.access(path, os.X_OK) or path.suffix in (".dylib", ".so")):
            with path.open("rb") as file:
                if file.read(4) in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xca\xfe\xba\xbe"):
                    executeCommand("codesign", "--force", "--options", "runtime", "--entitlements", entitlements,
                                   "--sign", CODESIGN_IDENTITY, path)


def createArchive():
    archive = DIST / f"heavy-toolchain-{HOST.replace('x86_64', 'x64')}.tar.xz"
    DIST.mkdir(parents=True, exist_ok=True)
    print(f"Writing {archive}", flush=True)
    with tarfile.open(archive, "w:xz", preset=9) as bundle:
        bundle.add(OUTPUT, arcname="Toolchain")

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    prepare()
    packageClang()
    packageArmGcc()
    if WINDOWS:
        packageWindowsTools()
    else:
        packageMake()
    packagePkgconf()
    packageDFU()
    packageFirmwareSender()
    if LINUX:
        packageLinuxSysroot()
    packageDPF()
    packageLibDaisy()
    packageOwlProgram()
    packageHvcc()
    packageResources()
    if MACOS:
        codesignMacOS()
    createArchive()
