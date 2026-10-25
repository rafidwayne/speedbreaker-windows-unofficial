#!/bin/bash
# SLOW, DO ONCE: default.xex -> ppc/ (generated C++) -> /home/claude/libNfsmwRecompLib.a
#   usage: win-build/ppc.sh /path/to/default.xex
# The result only changes if the XEX, config/, patches/xenonrecomp/ or build_ppc.sh change.
# Keep (or cache) ppc/ and the .a: win-build/runtime.sh then rebuilds the exe in minutes.
# Resumable: finished objects in /home/claude/ppcobj are kept. JOBS=N overrides the default
# (one per CPU, at most one per 2 GB RAM; the RAM per clang process is not measured).
set -euo pipefail
W=/home/claude; D=$W/deps
REPO="$(cd "$(dirname "$0")/.." && pwd)"; SRC=$W/speedbreaker
ln -sfn "$REPO" $SRC
XEX="$(readlink -f "${1:?usage: ppc.sh /path/to/default.xex}")"
echo "aebdf3c14d1e4e4ed2c130d94bc1a0e97bd6d5bf39bdfdef33c3909c9cc4ba4c  $XEX" | sha256sum -c - >/dev/null \
  || { echo "default.xex is not the supported USA (NTSC-U) build" >&2; exit 2; }
[ -f $D/all_ok ] && [ -x $SRC/tools/XenonRecomp/build/XenonRecomp/XenonRecomp ] || { echo "run win-build/toolchain.sh first" >&2; exit 2; }
if [ -z "${JOBS:-}" ]; then
  mem_gb=$(awk '/MemTotal/ {printf "%d", $2/1048576}' /proc/meminfo)
  JOBS=$(( mem_gb / 2 )); [ "$JOBS" -ge 1 ] || JOBS=1
  [ "$JOBS" -le "$(nproc)" ] || JOBS=$(nproc)
fi
export JOBS
mkdir -p $SRC/game/files $SRC/ppc
cp "$XEX" $SRC/game/files/default.xex
cd $SRC && tools/XenonRecomp/build/XenonRecomp/XenonRecomp config/nfsmw.toml tools/XenonRecomp/XenonUtils/ppc_context.h
rm -f $SRC/game/files/default.xex $W/ppc_fail.log $W/ppc_done
echo "compiling generated code, $JOBS at a time"
$W/build_ppc.sh
[ ! -f $W/ppc_fail.log ] || { echo "these files failed:"; cat $W/ppc_fail.log; exit 1; }
[ "$(ls $SRC/ppc/*.cpp | wc -l)" = "$(ls $W/ppcobj/*.o | wc -l)" ] || { echo "object count mismatch" >&2; exit 1; }
rm -f $W/libNfsmwRecompLib.a
x86_64-w64-mingw32-ar rcs $W/libNfsmwRecompLib.a $W/ppcobj/*.o
echo "PPC_OK $(du -h $W/libNfsmwRecompLib.a | cut -f1)"
