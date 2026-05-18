#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "error: missing $1" >&2
    echo "run: pnpm install" >&2
    exit 1
  fi
}

require_file node_modules/v86/build/libv86.js
require_file node_modules/v86/build/v86.wasm
require_file node_modules/xterm/lib/xterm.js
require_file node_modules/xterm/css/xterm.css
require_file node_modules/xterm-addon-fit/lib/xterm-addon-fit.js

mkdir -p bios

cp node_modules/v86/build/libv86.js libv86.js
cp node_modules/v86/build/v86.wasm v86.wasm
cp node_modules/xterm/lib/xterm.js xterm.js
cp node_modules/xterm/css/xterm.css xterm.css
cp node_modules/xterm-addon-fit/lib/xterm-addon-fit.js xterm-addon-fit.js

echo "synced browser runtime vendor assets"

if [[ ! -f bios/seabios.bin || ! -f bios/vgabios.bin ]]; then
  cat >&2 <<'EOF'
warning: BIOS files are not shipped in the v86 npm package.
Fetch runtime artifacts to provide:
  bios/seabios.bin
  bios/vgabios.bin
EOF
fi
