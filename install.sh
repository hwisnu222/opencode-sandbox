#!/usr/bin/env bash
# Install opencode-sandbox for the current user (no sudo needed).
#
# Usage:  ./install.sh [--no-build] [--force-config]
#   --no-build      skip building the image (build later with: oc --oc-rebuild)
#   --force-config  overwrite an existing opencode.jsonc in the data folder
#
# Locations (override with environment variables):
#   OC_HOME   sandbox data   (default: ~/.local/share/opencode-sandbox)
#   BIN_DIR   command folder (default: ~/.local/bin)
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OC_HOME="${OC_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode-sandbox}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

BUILD=1
FORCE_CONFIG=0
for arg in "$@"; do
  case "$arg" in
    --no-build) BUILD=0 ;;
    --force-config) FORCE_CONFIG=1 ;;
    -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install: unknown argument: $arg" >&2; exit 1 ;;
  esac
done

die() { echo "install: error: $*" >&2; exit 1; }

for f in bin/oc container/Containerfile config/opencode.jsonc; do
  [ -f "$SRC_DIR/$f" ] || die "file not found in repo: $f"
done

if [ "$BUILD" -eq 1 ]; then
  command -v podman >/dev/null 2>&1 || die "podman is not installed. Run: sudo dnf install podman (or use --no-build)"
fi

mkdir -p "$OC_HOME" "$BIN_DIR"

install -m 644 "$SRC_DIR/container/Containerfile" "$OC_HOME/Containerfile"

if [ -f "$OC_HOME/opencode.jsonc" ] && [ "$FORCE_CONFIG" -eq 0 ]; then
  if ! cmp -s "$SRC_DIR/config/opencode.jsonc" "$OC_HOME/opencode.jsonc"; then
    install -m 644 "$SRC_DIR/config/opencode.jsonc" "$OC_HOME/opencode.jsonc.new"
    echo "install: kept your existing opencode.jsonc (you probably edited it)."
    echo "         The new version was saved as $OC_HOME/opencode.jsonc.new"
    echo "         Use --force-config to overwrite."
  fi
else
  install -m 644 "$SRC_DIR/config/opencode.jsonc" "$OC_HOME/opencode.jsonc"
fi

install -m 755 "$SRC_DIR/bin/oc" "$BIN_DIR/oc"
echo "install: installed -> $BIN_DIR/oc"

if [ "$BUILD" -eq 1 ]; then
  echo "install: building image (a few minutes on the first run)..."
  OC_HOME="$OC_HOME" "$BIN_DIR/oc" --oc-rebuild
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo
    echo "Warning: $BIN_DIR is not on your PATH. Add this to ~/.bashrc:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

cat <<'DONE'

Done. Next steps:
  oc --oc-doctor        # check the environment
  cd ~/path/to/project
  oc auth login         # once
  oc                    # start OpenCode
DONE
