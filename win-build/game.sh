#!/bin/bash
# Full build = ppc.sh (slow, once) + runtime.sh (fast). usage: win-build/game.sh /path/to/default.xex
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
"$HERE/ppc.sh" "${1:?usage: game.sh /path/to/default.xex}"
"$HERE/runtime.sh"
