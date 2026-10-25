#!/bin/bash
# Stage 1 of the Windows build: everything that does NOT need default.xex.
#   apt packages -> patched XenonRecomp -> SDL3, glslang, Vulkan import lib, FFmpeg XMA decoders
# Idempotent: finished pieces are skipped, so a re-run (or a restored CI cache) costs seconds.
# Ubuntu 24.04 or WSL2. Needs sudo only for apt and for creating /home/claude.
set -euo pipefail
W=/home/claude; D=$W/deps
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SUDO=""; [ "$(id -u)" = 0 ] || SUDO=sudo

# The helper scripts use fixed /home/claude paths; link the checkout there.
$SUDO mkdir -p $W && $SUDO chown "$(id -u):$(id -g)" $W
ln -sfn "$REPO" $W/speedbreaker
SRC=$W/speedbreaker

echo "== apt"
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq || true      # a dead third-party apt source must not stop the build
$SUDO apt-get install -y -qq ccache git curl patch clang lld cmake ninja-build nasm make python3 pkg-config \
  g++-mingw-w64-x86-64-posix gcc-mingw-w64-x86-64-posix mingw-w64-x86-64-dev binutils-mingw-w64-x86-64
$SUDO update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix || true
$SUDO update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix || true
# XenonUtils includes "Windows.h" (capital W); mingw's header is lowercase.
$SUDO ln -sf /usr/x86_64-w64-mingw32/include/windows.h /usr/x86_64-w64-mingw32/include/Windows.h

cp "$SRC"/win-build/mingw-toolchain.cmake "$SRC"/win-build/deps.sh "$SRC"/win-build/build_ppc.sh $W/
chmod +x $W/deps.sh $W/build_ppc.sh

echo "== XenonRecomp (pinned commit + patches/xenonrecomp)"
BASE=ddd128bcca99fe8bfbb99bea583c972351fa6ace
mkdir -p "$SRC/tools" && cd "$SRC/tools"
# NOT "git clone --recursive": XenonRecomp's simde submodule pins a commit that is no longer on any
# branch, so the recursive clone aborts. Clone plain, check out the base, then fetch each submodule's
# pinned commit by SHA if the normal update can't find it.
[ -d XenonRecomp/.git ] || git clone -q https://github.com/hedge-dev/XenonRecomp.git
cd XenonRecomp
if ! git rev-parse -q --verify nfsmw >/dev/null; then
  git checkout -q -b nfsmw "$BASE"
  git submodule init -q
  for p in $(git submodule status | awk '{print $2}'); do
    sha=$(git ls-tree HEAD "$p" | awk '{print $3}')
    git submodule update -q --recursive -- "$p" 2>/dev/null || {
      git -C "$p" fetch -q origin "$sha" && git -C "$p" checkout -q "$sha"
    }
    [ "$(git -C "$p" rev-parse HEAD)" = "$sha" ] || { echo "submodule $p is not at $sha" >&2; exit 1; }
    git -C "$p" reset -q --hard
  done
  git -c user.name=x -c user.email=x@x.invalid am -q "$SRC"/patches/xenonrecomp/*.patch
fi
if [ ! -x build/XenonRecomp/XenonRecomp ]; then
  cmake -Wno-deprecated -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ "-DCMAKE_CXX_FLAGS=-include cstdlib" >/dev/null
  ninja -C build XenonRecomp
fi

echo "== dependency sources"
mkdir -p $D/src && cd $D/src
get() { [ -d "$1" ] && [ -n "$(ls -A "$1")" ] && return 0; mkdir -p "$1"; curl -fsSL --retry 3 "$2" | tar -xz -C "$1" --strip-components=1; }
get Vulkan-Headers https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/vulkan-sdk-1.4.357.0.tar.gz
get SPIRV-Headers  https://github.com/KhronosGroup/SPIRV-Headers/archive/refs/tags/vulkan-sdk-1.4.357.0.tar.gz
get SPIRV-Tools    https://github.com/KhronosGroup/SPIRV-Tools/archive/refs/tags/vulkan-sdk-1.4.357.0.tar.gz
get glslang        https://github.com/KhronosGroup/glslang/archive/refs/tags/16.6.0.tar.gz
get Vulkan-Loader  https://github.com/KhronosGroup/Vulkan-Loader/archive/refs/tags/vulkan-sdk-1.4.357.0.tar.gz
get SDL3           https://github.com/libsdl-org/SDL/releases/download/release-3.4.16/SDL3-3.4.16.tar.gz
get FFmpeg         https://codeload.github.com/FFmpeg/FFmpeg/tar.gz/refs/tags/n7.1.1

echo "== dependencies (SDL3, glslang, Vulkan, FFmpeg XMA)"
JOBS="${JOBS:-$(nproc)}" $W/deps.sh
[ -f $D/all_ok ] || { echo "deps.sh did not finish" >&2; exit 1; }
echo "TOOLCHAIN_OK"
