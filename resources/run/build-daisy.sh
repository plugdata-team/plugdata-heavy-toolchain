#!/bin/sh
GENERATOR=daisy
HV_GENERATOR=daisy
MODE=build
. "$(dirname -- "$0")/common.sh"
BOARD=pod
BOARD_FILE=
USB_MIDI=false
DEBUG_PRINTING=false
BLOCKSIZE=48
SAMPLERATE=48000
PATCH_SIZE=small
LINKER=
APP_TYPE=none
OPTIONS_HELP='  --board BOARD       pod, petal, patch, patch_init, field, versio, terrarium, hothouse,
                      simple or custom (default: pod)
  --board-file FILE   Board definition JSON for --board custom
  --usb-midi          MIDI over USB (not with --debug-printing)
  --debug-printing    Print debug output over USB
  --blocksize N       Audio block size, 1-256 (default: 48)
  --samplerate RATE   8000, 16000, 32000, 48000 or 96000 (default: 48000)
  --patch-size SIZE   small, big, big-sdram, huge, huge-sdram or custom (default: small)
  --linker FILE       Linker script for --patch-size custom
  --app-type TYPE     none, sram or qspi bootloader for --patch-size custom (default: none)'
parse_option() {
    case $1 in
        --board|--board-file|--blocksize|--samplerate|--patch-size|--linker|--app-type)
            [ "$#" -ge 2 ] || fail "Missing value for $1";;
    esac
    case $1 in
        --board)
            case $2 in pod|petal|patch|patch_init|field|versio|terrarium|hothouse|simple|custom) ;; *) fail "Unknown Daisy board: $2";; esac
            BOARD=$2; CONSUMED=2;;
        --board-file) BOARD_FILE=$(absolute_file "$2"); CONSUMED=2;;
        --usb-midi) USB_MIDI=true; CONSUMED=1;;
        --debug-printing) DEBUG_PRINTING=true; CONSUMED=1;;
        --blocksize)
            case $2 in ''|*[!0-9]*) fail 'Blocksize must be a number';; esac
            [ "$2" -ge 1 ] && [ "$2" -le 256 ] || fail 'Blocksize must be between 1 and 256'
            BLOCKSIZE=$2; CONSUMED=2;;
        --samplerate)
            case $2 in 8000|16000|32000|48000|96000) ;; *) fail "Unsupported samplerate: $2";; esac
            SAMPLERATE=$2; CONSUMED=2;;
        --patch-size)
            case $2 in small|big|big-sdram|huge|huge-sdram|custom) ;; *) fail "Unknown patch size: $2";; esac
            PATCH_SIZE=$2; CONSUMED=2;;
        --linker) LINKER=$(absolute_file "$2"); CONSUMED=2;;
        --app-type)
            case $2 in none|sram|qspi) ;; *) fail 'App type must be none, sram or qspi';; esac
            APP_TYPE=$2; CONSUMED=2;;
    esac
}
write_meta() {
    case $BOARD in
        custom)
            [ -n "$BOARD_FILE" ] || fail 'A custom board needs --board-file FILE'
            board="\"board_file\": $(json_string "$BOARD_FILE")";;
        versio|terrarium|hothouse|simple) board="\"board_file\": $(json_string "$TOOLCHAIN_ROOT/etc/$BOARD.json")";;
        *) board="\"board\": \"$BOARD\"";;
    esac
    # Bigger patches move to SRAM or QSPI flash, started by the Daisy bootloader
    linker=
    bootloader=
    case $PATCH_SIZE in
        big) linker=../../libdaisy/core/STM32H750IB_sram.lds; bootloader=BOOT_SRAM;;
        big-sdram) linker=$TOOLCHAIN_ROOT/etc/linkers/sram_linker_sdram.lds; bootloader=BOOT_SRAM;;
        huge) linker=../../libdaisy/core/STM32H750IB_qspi.lds; bootloader=BOOT_QSPI;;
        huge-sdram) linker=$TOOLCHAIN_ROOT/etc/linkers/qspi_linker_sdram.lds; bootloader=BOOT_QSPI;;
        custom)
            [ -n "$LINKER" ] || fail 'A custom patch size needs --linker FILE'
            linker=$LINKER
            case $APP_TYPE in sram) bootloader=BOOT_SRAM;; qspi) bootloader=BOOT_QSPI;; esac;;
    esac
    printf '{\n  "daisy": {\n    %s,\n    "samplerate": %s' "$board" "$SAMPLERATE"
    # USB is either MIDI or debug output
    if [ "$DEBUG_PRINTING" = true ]; then
        printf ',\n    "debug_printing": true'
    elif [ "$USB_MIDI" = true ]; then
        printf ',\n    "usb_midi": true'
    fi
    if [ "$BLOCKSIZE" != 48 ]; then printf ',\n    "blocksize": %s' "$BLOCKSIZE"; fi
    if [ -n "$linker" ]; then printf ',\n    "linker_script": %s' "$(json_string "$linker")"; fi
    if [ -n "$bootloader" ]; then printf ',\n    "bootloader": "%s"' "$bootloader"; fi
    printf '\n  }\n}\n'
}
parse_args "$@"
copy_library libdaisy libdaisy
run_command rm -rf -- "$OUTPUT/c"
# Upstream make expands LDSCRIPT without quotes. Localize a supplied linker
# script so an installation/custom linker path containing spaces works too.
(
    run_command cd -- "$OUTPUT/daisy/source"
    linker=$(sed -n 's/^LDSCRIPT = //p' Makefile)
    if [ -n "$linker" ] && [ "$linker" != linker.lds ]; then
        run_command cp -- "$linker" linker.lds
        run_command sed 's|^LDSCRIPT = .*|LDSCRIPT = linker.lds|' Makefile > Makefile.tmp
        run_command mv -- Makefile.tmp Makefile
    fi
)
if [ "$MODE" != source ]; then
    run_command cd -- "$OUTPUT/daisy/source"
    run_command make -j"$JOBS" "SHELL=$SHELL" "PROJECT_NAME=$NAME"
    run_command cp -- "build/HeavyDaisy_$NAME.bin" "$OUTPUT/$NAME.bin"
    if [ "$MODE" = flash ]; then
        # Let dfu-util/make report failures; do not turn all DFU errors into success.
        run_command make "SHELL=$SHELL" "PROJECT_NAME=$NAME" program-dfu
    fi
    # Keep only the firmware; the project and libDaisy are regenerated by every export.
    run_command cd -- "$OUTPUT"
    run_command rm -rf -- daisy libdaisy
fi
