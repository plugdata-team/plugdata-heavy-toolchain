#!/bin/sh
# Utility entry point for build diagnostics and custom commands.
. "$(dirname -- "$0")/common.sh"
[ "$#" -gt 0 ] || set -- "$TOOLCHAIN_SHELL"
log_command "$@"
exec "$@"
