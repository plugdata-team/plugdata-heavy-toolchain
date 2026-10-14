# Shared POSIX-shell setup. Sourced by entry points, never executed directly.
set -eu
# Always emit ANSI styling: plugdata captures output through a pipe.
log_command() {
    printf '\033[1;32m> %s\033[0m\n' "$*" >&2
}
run_command() {
    log_command "$@"
    "$@"
}
fail() { printf '%s\n' "$*" >&2; exit 2; }
RUN_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TOOLCHAIN_ROOT=$(CDPATH= cd -- "$RUN_DIR/.." && pwd -P)
EXE=
if [ -f "$TOOLCHAIN_ROOT/bin/sh.exe" ]; then
    EXE=.exe
    TOOLCHAIN_SHELL="$TOOLCHAIN_ROOT/bin/sh.exe"
    # Windows make needs a shell name without spaces; resolve it through PATH.
    SHELL=sh
    # BusyBox-w32 understands drive-letter paths and semicolon-separated PATH.
    PATH="$TOOLCHAIN_ROOT/bin;$TOOLCHAIN_ROOT/packages/windows-tools/bin;$TOOLCHAIN_ROOT/packages/clang/bin;$TOOLCHAIN_ROOT/packages/arm-gcc/bin;$PATH"
else
    TOOLCHAIN_SHELL=/bin/sh
    SHELL=/bin/sh
    PATH="$TOOLCHAIN_ROOT/bin:$TOOLCHAIN_ROOT/packages/clang/bin:$TOOLCHAIN_ROOT/packages/arm-gcc/bin:$PATH"
fi
MAKESHELL=$SHELL
CC=clang
CXX=clang++
AR=llvm-ar
# Clang only colours diagnostics on a terminal; this appends -fcolor-diagnostics to every
# Clang command line ('#' keeps it quiet). A Clang config file can't: colour is decided before it loads.
CCC_OVERRIDE_OPTIONS='#+-fcolor-diagnostics'
export PATH SHELL MAKESHELL CC CXX AR TOOLCHAIN_ROOT CCC_OVERRIDE_OPTIONS
if [ -d "$TOOLCHAIN_ROOT/sysroot" ]; then
    PKG_CONFIG_SYSROOT_DIR="$TOOLCHAIN_ROOT/sysroot"
    PKG_CONFIG_LIBDIR="$PKG_CONFIG_SYSROOT_DIR/usr/lib64/pkgconfig:$PKG_CONFIG_SYSROOT_DIR/usr/share/pkgconfig"
    PKG_CONFIG_PATH=
    # Apply the sysroot to parsed -I/-L fragments, not raw .pc variables.
    # pkgconf's default variable rewriting splits paths containing spaces.
    PKG_CONFIG_FDO_SYSROOT_RULES=1
    export PKG_CONFIG_SYSROOT_DIR PKG_CONFIG_LIBDIR PKG_CONFIG_PATH PKG_CONFIG_FDO_SYSROOT_RULES
fi
JOBS=${TOOLCHAIN_JOBS:-4}
case $JOBS in ''|*[!0-9]*|0) fail 'TOOLCHAIN_JOBS must be a positive integer';; esac

usage() {
    printf '%s\n' "Usage: sh build-$GENERATOR.sh input_patch project_name project_copyright [options] [-- search_path ...]" \
        '  --output DIR     Output directory (default: ./project_name)' \
        '  --meta FILE      Heavy metadata JSON (DPF/Daisy settings)' \
        "  --mode MODE      source or build (default: $MODE); Daisy also flash; OWL also load/store" \
        '  --board OWL1|OWL2|OWL3   OWL target (default: OWL2)' \
        '  --slot NUMBER    OWL store slot (default: 1)' \
        '  --emsdk DIR      Activated Emscripten SDK for WASM' \
        '  --pd-bin DIR     Directory containing pd.dll for Windows Pd builds' \
        '  --gui            DPF: parse GUI objects, required for a NanoVG UI (enable_ui: 2)'
}
absolute_file() {
    [ -f "$1" ] || fail "File not found: $1"
    printf '%s/%s\n' "$(CDPATH= cd -- "$(dirname -- "$1")" && pwd -P)" "$(basename -- "$1")"
}
parse_args() {
    if [ "${1:-}" = --help ]; then usage; exit 0; fi
    [ "$#" -ge 3 ] || { usage >&2; exit 2; }
    INPUT=$(absolute_file "$1")
    NAME=$2
    COPYRIGHT=$3
    # Names become C identifiers, filenames and make variables. Do not pass
    # shell or make metacharacters through to generated build recipes.
    case $NAME in ''|[0-9]*|*[!a-zA-Z0-9_]*) fail 'Project name must be a C identifier (letters, digits, underscores)';; esac
    OUTPUT="$PWD/$NAME"
    META=${DEFAULT_META:-}
    BOARD=OWL2
    SLOT=1
    EMSDK_DIR=${EMSDK:-}
    PD_BIN=
    GUI=
    shift 3
    while [ "$#" -gt 0 ]; do
        case $1 in
            --) shift; break;;
            --help) usage; exit 0;;
            --gui) GUI=1; shift;;
            --output|--meta|--mode|--board|--slot|--emsdk|--pd-bin)
                [ "$#" -ge 2 ] || fail "Missing value for $1"
                case $1 in
                    --output) OUTPUT=$2;;
                    --meta) META=$(absolute_file "$2");;
                    --mode) MODE=$2;;
                    --board) BOARD=$2;;
                    --slot) SLOT=$2;;
                    --emsdk) EMSDK_DIR=$2;;
                    --pd-bin) PD_BIN=$2;;
                esac
                shift 2;;
            *) fail "Unknown option: $1 (put search paths after --)";;
        esac
    done
    case "$GENERATOR:$MODE" in
        cpp:source|unity:source|wwise:source|fmod:source|wasm:source|wasm:build|pd:source|pd:build|dpf:source|dpf:build|daisy:source|daisy:build|daisy:flash|owl:source|owl:build|owl:load|owl:store) ;;
        *) fail "Unsupported mode '$MODE' for $GENERATOR";;
    esac
    [ -z "$GUI" ] || [ "$GENERATOR" = dpf ] || fail '--gui is only supported for DPF'
    case $BOARD in OWL1|OWL2|OWL3) ;; *) fail 'OWL board must be OWL1, OWL2 or OWL3';; esac
    case $SLOT in ''|*[!0-9]*) fail 'OWL slot must be a non-negative integer';; esac
    [ -n "$OUTPUT" ] || fail 'Output directory cannot be empty'
    run_command mkdir -p -- "$OUTPUT"
    OUTPUT=$(CDPATH= cd -- "$OUTPUT" && pwd -P)
    [ "$OUTPUT" != / ] && [ "$OUTPUT" != "$TOOLCHAIN_ROOT" ] || fail 'Choose a separate project output directory'
    # Keep search arguments as individual words: no eval or shell command strings.
    generate "$@"
}
generate() {
    if [ "$GENERATOR" = wasm ]; then
        [ -n "$EMSDK_DIR" ] || fail 'WASM requires --emsdk DIR (or EMSDK)'
        EMSDK=$(CDPATH= cd -- "$EMSDK_DIR" && pwd -P)
        export EMSDK
        [ -f "$EMSDK/emsdk_env.sh" ] || fail 'emsdk_env.sh not found'
        # The SDK environment script may reference unset optional variables.
        set +u
        . "$EMSDK/emsdk_env.sh"
        set -u
    fi
    if [ "$GENERATOR" = pd ] && [ "$MODE" = build ] && [ -n "$EXE" ]; then
        [ -f "$PD_BIN/pd.dll" ] || fail 'Windows Pd builds require --pd-bin DIR containing pd.dll'
        PDBINDIR=$(CDPATH= cd -- "$PD_BIN" && pwd -P)
        export PDBINDIR
    fi
    # hvcc consumes the remaining search directories after -p.
    if [ "$#" -gt 0 ]; then set -- -p "$@"; fi
    if [ -n "$META" ]; then set -- -m "$META" "$@"; fi
    if [ -n "$COPYRIGHT" ]; then set -- --copyright "$COPYRIGHT" "$@"; fi
    # NanoVG DPF UIs are generated from the GUI IR that --gui produces.
    if [ -n "$GUI" ]; then set -- --gui "$@"; fi
    run_command "$TOOLCHAIN_ROOT/bin/Heavy/Heavy$EXE" "$INPUT" -o "$OUTPUT" -n "$NAME" -v -g "$HV_GENERATOR" "$@"
    run_command rm -rf -- "$OUTPUT/ir" "$OUTPUT/hv"
    if [ -n "$META" ] && [ "$META" != "$OUTPUT/meta.json" ]; then run_command cp -- "$META" "$OUTPUT/meta.json"; fi
}
copy_library() {
    run_command mkdir -p -- "$OUTPUT/$2"
    run_command cp -R -- "$TOOLCHAIN_ROOT/lib/$1/." "$OUTPUT/$2/"
}
make_project() {
    # Command-line compiler variables override make's built-in cc/g++ defaults.
    # LLVM's Windows triple can contain "gnu" before "windows"; older DPF
    # detection mistakes that for GNU/Hurd. State the host explicitly.
    if [ -n "$EXE" ]; then set -- WINDOWS=true "$@"; fi
    run_command make -j"$JOBS" "SHELL=$SHELL" CC=clang CXX=clang++ AR=llvm-ar "$@"
}
