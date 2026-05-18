#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

GH_REPO="${GH_REPO:-slashlifeai/agent-gate-incident-replay}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required to parse manifest.json" >&2
  exit 1
fi

read_manifest() {
  python3 -c "import json,sys; m=json.load(open('manifest.json')); print(m$1)"
}

ISO_NAME=$(read_manifest "['iso']")
ISO_SHA=$(read_manifest "['iso_sha256']")
ISO_VERSION=$(read_manifest "['iso_version']")
SAVESTATE_NAME=$(read_manifest "['savestate']")
SAVESTATE_SHA=$(read_manifest "['savestate_sha256']")
V86_REF=$(read_manifest "['bios']['v86_ref']")
SEABIOS_SHA=$(read_manifest "['bios']['seabios_sha256']")
VGABIOS_SHA=$(read_manifest "['bios']['vgabios_sha256']")

RELEASE_TAG="${RELEASE_TAG:-runtime-${ISO_VERSION}}"

if command -v sha256sum >/dev/null 2>&1; then
  sha256_of() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  echo "error: need sha256sum or shasum" >&2
  exit 1
fi

verify() {
  local path="$1" expected="$2"
  local actual
  actual=$(sha256_of "$path")
  if [[ "$actual" != "$expected" ]]; then
    echo "error: sha256 mismatch for $path" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    rm -f "$path"
    exit 1
  fi
}

have_matching_file() {
  local path="$1" expected="$2"
  [[ -f "$path" ]] && [[ "$(sha256_of "$path")" == "$expected" ]]
}

gh_available() {
  command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
}

fetch_release_asset() {
  local name="$1" expected="$2"
  if have_matching_file "$name" "$expected"; then
    echo "ok    $name (cached)"
    return 0
  fi
  echo "fetch $name from release $RELEASE_TAG"
  if gh_available; then
    gh release download "$RELEASE_TAG" \
      --repo "$GH_REPO" \
      --pattern "$name" \
      --dir . \
      --clobber
  else
    local url="https://github.com/${GH_REPO}/releases/download/${RELEASE_TAG}/${name}"
    curl -fL --retry 3 -o "${name}.tmp" "$url"
    mv "${name}.tmp" "$name"
  fi
  verify "$name" "$expected"
  echo "ok    $name"
}

fetch_v86_bios() {
  local name="$1" expected="$2"
  local out="bios/${name}"
  if have_matching_file "$out" "$expected"; then
    echo "ok    $out (cached)"
    return 0
  fi
  echo "fetch $out from copy/v86@${V86_REF:0:12}"
  mkdir -p bios
  local url="https://raw.githubusercontent.com/copy/v86/${V86_REF}/bios/${name}"
  curl -fL --retry 3 -o "${out}.tmp" "$url"
  mv "${out}.tmp" "$out"
  verify "$out" "$expected"
  echo "ok    $out"
}

if ! gh_available; then
  cat >&2 <<EOF
note: 'gh' CLI not authenticated or not installed.
      Falling back to anonymous HTTPS download for release assets.
      Install: https://cli.github.com  (then: gh auth login)
EOF
fi

fetch_release_asset "$ISO_NAME" "$ISO_SHA"
fetch_release_asset "$SAVESTATE_NAME" "$SAVESTATE_SHA"
fetch_v86_bios "seabios.bin" "$SEABIOS_SHA"
fetch_v86_bios "vgabios.bin" "$VGABIOS_SHA"

echo
echo "runtime artifacts ready. next:"
echo "  pnpm install && pnpm sync:vendor   # browser vendor JS/WASM/CSS"
echo "  python3 -m http.server 8080"
