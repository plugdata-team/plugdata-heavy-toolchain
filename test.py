#!/usr/bin/env python3
"""Test a built toolchain end-to-end, including exports and relocation.

Run after build.py, or pass the path to an extracted Toolchain bundle.
No third-party Python packages or initialized submodules are needed.
"""
import os
import re
import json
import locale
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile


def check(condition, message):
    if not condition:
        raise RuntimeError(message)


def audit_linux(root, reader=None):
    """Check ELF symbol version requirements, including bundled shared libraries."""
    reader = reader or root / 'packages/clang/bin/llvm-readelf'
    for path in root.rglob('*'):
        if not path.is_file() or path.is_symlink():
            continue
        with path.open('rb') as f:
            if f.read(4) != b'\x7fELF':
                continue
        output = subprocess.check_output([str(reader) if reader.is_file() else 'readelf',
                                          '--version-info', str(path)], text=True)
        versions = [tuple(map(int, v.split('.'))) for v in re.findall(r'GLIBC_([0-9.]+)', output)]
        if versions and max(versions) > (2, 28):
            raise RuntimeError(f'{path} requires GLIBC {max(versions)}, exceeding 2.28')


def run_tests(root, emsdk=None):
    root = root.resolve()
    if sys.platform.startswith('linux'):
        audit_linux(root)
    check((root / 'VERSION').read_text().strip(), 'Missing toolchain version')
    # plugdata builds its export settings from these, and runs the scripts they name
    definitions = sorted((root / 'exporters').glob('*.json'))
    check(definitions, 'Missing exporter definitions')
    for definition in definitions:
        exporter = json.loads(definition.read_text())
        scripts = [exporter['script']] + [option['script'] for section in exporter.get('sections', [])
                                          for setting in section['settings'] for option in setting.get('options', [])
                                          if isinstance(option, dict) and 'script' in option]
        for script in scripts:
            check((root / 'run' / script).is_file(), f'{definition.name} names a missing script: {script}')
    shell = root / 'bin/sh.exe' if os.name == 'nt' else Path('/bin/sh')
    check(shell.is_file(), f'Missing shell: {shell}')
    if os.name != 'nt':
        check(not (root / 'bin/sh').exists() and not (root / 'bin/busybox').exists(),
              'Unix bundle should use the system shell and utilities')
    def run(*args, cwd=None):
        print('RUN:', ' '.join(map(str, args)), flush=True)
        subprocess.run([str(shell), str(root / 'run/exec.sh'), *map(str, args)], cwd=cwd, check=True)
    def check_only(folder, *names):
        # Binary builds clean up their project, leaving only the results.
        left = sorted(path.name for path in folder.iterdir())
        check(left == sorted(names), f'{folder.name} should only contain {sorted(names)}, not {left}')
    run('clang', '--version')
    run('arm-none-eabi-gcc', '--version')
    run('make', '--version')
    run('pkgconf', '--version')
    run('pkg-config', '--version')
    run('dfu-util', '--version')
    run('dfu-prefix', '--version')
    run('dfu-suffix', '--version')
    # Upstream FirmwareSender deliberately returns -1 after displaying help.
    firmware = root / 'bin' / ('FirmwareSender.exe' if os.name == 'nt' else 'FirmwareSender')
    help_result = subprocess.run([str(firmware), '--help'], capture_output=True, text=True)
    check(help_result.returncode in (255, -1, 4294967295), help_result)
    check('usage:' in help_result.stderr and 'FirmwareSender' in help_result.stderr, help_result.stderr)
    for name in ('DPF', 'dpf-widgets', 'pdvg', 'OwlProgram', 'libdaisy'):
        check((root / 'lib' / name).is_dir(), f'Missing bundled library: {name}')
    archives = [root / 'lib/libdaisy/build/libdaisy.a']
    for platform in ('OWL1', 'OWL2', 'OWL3'):
        archives += [root / 'lib/OwlProgram/Libraries' / platform / name
                     for name in ('libowlprg.a', 'libdaisysp.a')]
    for archive in archives:
        check(archive.is_file() and archive.stat().st_size > 8, archive)
        ar = root / 'packages/arm-gcc/bin' / ('arm-none-eabi-ar.exe' if os.name == 'nt' else 'arm-none-eabi-ar')
        check(subprocess.check_output([str(ar), 't', str(archive)]).strip(), archive)
    heavy = root / 'bin/Heavy' / ('Heavy.exe' if os.name == 'nt' else 'Heavy')
    run(heavy, '--help')
    with tempfile.TemporaryDirectory(prefix='toolchain smoke ') as tmp:
        work = Path(tmp)
        owl_copy = work / 'copied OwlProgram'
        for directory in ('Tools', 'lib'):
            source = root / 'lib/OwlProgram' / directory
            if source.is_dir():
                shutil.copytree(source, owl_copy / directory)
        copied_firmware = owl_copy / 'Tools' / firmware.name
        result = subprocess.run([str(copied_firmware), '--help'], capture_output=True, text=True)
        check(result.returncode in (255, -1, 4294967295) and 'usage:' in result.stderr, result.stderr)
        (work / 'hello.c').write_text('int main(void) { return 0; }\n')
        (work / 'hello.cpp').write_text('#include <string>\nint main() { return std::string("ok").size() != 2; }\n')
        (work / 'Makefile').write_text('all:\n\tmkdir -p out\n\t$(CC) hello.c -o out/hello.exe\n\tcp hello.c out/copy.c\n\ttest -f out/copy.c\n')
        run('make', cwd=work)
        run(str(work / 'out/hello.exe'), cwd=work)
        run('clang++', 'hello.cpp', '-o', 'out/cpp.exe', cwd=work)
        run(str(work / 'out/cpp.exe'), cwd=work)
        if sys.platform.startswith('linux'):
            # Exercise GUI/audio development libraries without needing a display
            # or audio device. The clean-container CI job has no host headers.
            (work / 'sdk.c').write_text(
                '#include <X11/Xlib.h>\n#include <GL/gl.h>\n#include <alsa/asoundlib.h>\n'
                'void probe(void) { XOpenDisplay(0); glFlush(); snd_asoundlib_version(); }\n')
            (work / 'SDK.mk').write_text(
                'SDK_FLAGS := $(shell pkg-config --cflags --libs x11 gl alsa)\n'
                'all:\n\t$(CC) -shared -fPIC sdk.c $(SDK_FLAGS) -o out/sdk.so\n')
            run('make', '-f', 'SDK.mk', cwd=work)
            audit_linux(work / 'out', root / 'packages/clang/bin/llvm-readelf')
        run('arm-none-eabi-gcc', '-mcpu=cortex-m4', '-mthumb', '-ffreestanding', '-c', 'hello.c', '-o', 'arm.o', cwd=work)
        check((work / 'arm.o').stat().st_size > 0, 'Artifact check failed')
        for fpu in ('fpv4-sp-d16', 'fpv5-d16'):
            run('arm-none-eabi-gcc', '-mcpu=cortex-m7', '-mthumb',
                '-mfloat-abi=hard', '-mfpu=' + fpu, '--specs=nosys.specs',
                'hello.c', '-o', 'arm-' + fpu + '.elf', cwd=work)
        patch = work / 'patch with spaces.pd'
        patch.write_text('#N canvas 0 0 400 300 10;\n#X obj 10 10 osc~ 440;\n#X obj 10 50 dac~;\n#X connect 0 0 1 0;\n#X connect 0 0 1 1;\n')
        search = work / 'abstractions with spaces'
        search.mkdir()
        (search / 'test_tone.pd').write_text(
            '#N canvas 0 0 400 300 10;\n#X obj 10 10 osc~ 440;\n'
            '#X obj 10 50 outlet~;\n#X connect 0 0 1 0;\n')
        search_patch = work / 'search path test.pd'
        search_patch.write_text(patch.read_text().replace('osc~ 440', 'test_tone'))
        copyright = 'A "quote"; $(touch unwanted) & Unicode ©'
        run(shell, root / 'run/build-cpp.sh', search_patch, 'smoke', copyright,
            '--output', work / 'generated', '--', search, cwd=work)
        check(not (work / 'unwanted').exists(), 'Copyright was interpreted by the shell')
        check(not (work / 'generated/ir').exists(), 'Intermediate IR was not cleaned')
        # Heavy writes using Python's default encoding: UTF-8 or the Windows
        # locale code page, depending on the bundled Python configuration.
        encodings = {'utf-8', locale.getencoding()}
        expected = [copyright.encode(encoding) for encoding in encodings]
        check(any(text in path.read_bytes()
                  for path in (work / 'generated/c').glob('*.h') for text in expected),
              'Copyright was not preserved')
        for arguments in ((patch, 'bad;name', ''), (patch, 'smoke', '', '--output'),
                          (patch, 'smoke', '', '--mode', 'flash')):
            result = subprocess.run([str(shell), str(root / 'run/build-cpp.sh'),
                                     *map(str, arguments)], cwd=work, capture_output=True, text=True)
            check(result.returncode != 0, f'Invalid arguments accepted: {arguments}')
        bad_patch = work / 'invalid.pd'
        bad_patch.write_text('#N canvas 0 0 400 300 10;\n#X obj 10 10 nonexistent_toolchain_object;\n')
        failed = work / 'failed export'
        result = subprocess.run([str(shell), str(root / 'run/build-dpf.sh'),
                                 str(bad_patch), 'smoke', '', '--output', str(failed)],
                                cwd=work, capture_output=True, text=True)
        check(result.returncode != 0, 'Heavy failure was not propagated')
        check(not (failed / 'dpf').exists(), 'Export continued after Heavy failed')
        check(list((work / 'generated/c').glob('Heavy_smoke*')), 'hvcc generated no C/C++ context')
        for generator in ('unity', 'wwise', 'fmod'):
            output = work / generator
            run(shell, root / ('run/build-' + generator + '.sh'), patch, 'smoke', '', '--output', output)
            check(any(path.is_file() and path.stat().st_size for path in (output / generator).rglob('*')),
                  f'{generator} generated no integration sources')
        pd_output = work / 'pd external'
        pd_mode = 'source' if os.name == 'nt' else 'build'
        run(shell, root / 'run/build-pd.sh', patch, 'smoke', '', '--output', pd_output, '--mode', pd_mode)
        if os.name != 'nt':
            check(list(pd_output.glob('smoke~.pd_*')), 'Pd external was not built')
            check_only(pd_output, next(pd_output.glob('smoke~.pd_*')).name)
        else:
            check(list((pd_output / 'pdext').glob('*.c')), 'Pd external sources were not generated')
            print('SKIP: Windows Pd linking requires an external pd.dll; source generation passed.')
        metadata = work / 'dpf metadata.json'
        # Compile the PDVG UI on every platform to check its sources and the
        # patched DPF API. Loading it would require a display/audio device.
        metadata.write_text(json.dumps({'dpf': {'maker': 'plugdata', 'license': 'ISC',
                                               'plugin_formats': ['clap'], 'enable_ui': 2}}))
        dpf = work / 'dpf plugin'
        run(shell, root / 'run/build-dpf.sh', patch, 'smoke', '', '--output', dpf, '--meta', metadata, '--gui')
        check((dpf / 'meta.json').read_bytes() == metadata.read_bytes(), 'Metadata was not preserved')
        check((dpf / 'smoke.clap').exists(), 'DPF CLAP plugin was not built')
        check_only(dpf, 'meta.json', 'smoke.clap')
        if sys.platform.startswith('linux'):
            audit_linux(dpf, root / 'packages/clang/bin/llvm-readelf')
        daisy = work / 'daisy firmware'
        run(shell, root / 'run/build-daisy.sh', patch, 'smoke', '', '--output', daisy)
        check((daisy / 'smoke.bin').stat().st_size > 0, 'Artifact check failed')
        check_only(daisy, 'smoke.bin')
        for board in ('OWL1', 'OWL2', 'OWL3'):
            owl = work / ('owl firmware ' + board)
            run(shell, root / 'run/build-owl.sh', patch, 'smoke', '', '--output', owl, '--board', board)
            check((owl / 'smoke.bin').stat().st_size > 0, 'Artifact check failed')
            check_only(owl, 'smoke.bin')
        if emsdk:
            output = work / 'wasm export'
            run(shell, root / 'run/build-wasm.sh', patch, 'smoke', '',
                '--output', output, '--emsdk', emsdk)
            check(list(output.rglob('*.js')), 'WASM export generated no JavaScript')
        else:
            print('SKIP: WASM export requires --emsdk DIR (external Emscripten SDK).')


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle', type=Path, nargs='?',
                        default=Path(__file__).resolve().parent / '.toolchain/Toolchain')
    parser.add_argument('--emsdk', type=Path, help='Activated Emscripten SDK for the WASM export')
    args = parser.parse_args()
    root = args.bundle.resolve()
    emsdk = args.emsdk.resolve() if args.emsdk else None
    if not root.is_dir():
        parser.error('Build the toolchain first or pass its extracted bundle path')
    # Move rather than copy multi-gigabyte bundles; restore even on failure.
    # Keep the names short: Windows GCC resolves headers through long ../ paths limited to 260 characters.
    with tempfile.TemporaryDirectory(prefix='moved ', dir=root.parent) as tmp:
        moved = Path(tmp) / 'Tool chain'
        root.rename(moved)
        try:
            run_tests(moved, emsdk)
        finally:
            moved.rename(root)
    print('PASS: all requested toolchain checks passed.')


if __name__ == '__main__':
    main()
