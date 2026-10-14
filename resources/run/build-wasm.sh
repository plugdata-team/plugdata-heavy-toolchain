#!/bin/sh
GENERATOR=wasm
HV_GENERATOR=js
MODE=source
. "$(dirname -- "$0")/common.sh"
parse_args "$@"
run_command rm -rf -- "$OUTPUT/c"
