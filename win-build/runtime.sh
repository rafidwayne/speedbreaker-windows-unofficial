#!/bin/bash
# FAST, EVERY CHANGE: rebuild SpeedBreaker.exe from the runtime sources, reusing ppc/ and the
# prebuilt /home/claude/libNfsmwRecompLib.a from win-build/ppc.sh. No XEX needed.
# Incremental: re-run after an edit and only changed files recompile (ccache is used if installed).
set -euo pipefail
W=/home/claude; D=$W/deps
REPO="$(cd "$(dirname "$0")/.." && pwd)"; SRC=$W/speedbreaker
ln -sfn "$REPO" $SRC
[ -f $D/all_ok ] || { echo "run win-build/toolchain.sh first" >&2; exit 2; }
[ -s $W/libNfsmwRecompLib.a ] && ls $SRC/ppc/*.cpp >/dev/null 2>&1 || { echo "need ppc/ and libNfsmwRecompLib.a: run win-build/ppc.sh (once) or restore them" >&2; exit 2; }
LAUNCH=""; command -v ccache >/dev/null && LAUNCH="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
cmake -S $SRC -B $W/build -G Ninja -DCMAKE_TOOLCHAIN_FILE=$W/mingw-toolchain.cmake -DCMAKE_BUILD_TYPE=Release $LAUNCH \
  -DSB_PPC_PREBUILT=$W/libNfsmwRecompLib.a -DFFMPEG_XMA=$D/ffmpeg-xma \
  -DVulkan_INCLUDE_DIR=$D/install/include -DVulkan_LIBRARY=$D/install/lib/libvulkan-1.a \
  -DCMAKE_PREFIX_PATH=$D/install "-DCMAKE_CXX_FLAGS=-include cstdlib -Wno-everything" "-DCMAKE_C_FLAGS=-Wno-everything" >/dev/null
ninja -C $W/build SpeedBreaker
x86_64-w64-mingw32-strip -o $W/SpeedBreaker.exe $W/build/runtime/SpeedBreaker.exe
sha256sum $W/SpeedBreaker.exe
echo "built $W/SpeedBreaker.exe"
