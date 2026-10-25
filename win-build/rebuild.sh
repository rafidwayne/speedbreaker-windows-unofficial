#!/bin/bash
# Both stages in one go: win-build/rebuild.sh /path/to/default.xex  ->  /home/claude/SpeedBreaker.exe
# (Run the stages separately while debugging: toolchain.sh needs no game files and can be cached.)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
"$HERE/toolchain.sh"
"$HERE/game.sh" "${1:?usage: rebuild.sh /path/to/default.xex}"
