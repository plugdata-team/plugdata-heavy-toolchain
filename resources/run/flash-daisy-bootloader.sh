#!/bin/sh
# Explicit hardware operation, separate from ordinary generation/builds.
. "$(dirname -- "$0")/common.sh"
[ "$#" -eq 0 ] || fail 'Usage: sh flash-daisy-bootloader.sh'
cd -- "$TOOLCHAIN_ROOT/lib/libdaisy/core"
log_command make "SHELL=$SHELL" program-boot
exec make "SHELL=$SHELL" program-boot
