#!/usr/bin/env bash
# Remove opencode-sandbox.
#
# Usage:  ./uninstall.sh [--purge]
#   (no option)  remove the oc command and the data folder (Containerfile, config)
#   --purge      also remove the image and the login volume (opencode-data)
set -euo pipefail

OC_HOME="${OC_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode-sandbox}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

PURGE=0
for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    -h|--help) sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "uninstall: unknown argument: $arg" >&2; exit 1 ;;
  esac
done

rm -f "$BIN_DIR/oc"
echo "uninstall: removed $BIN_DIR/oc"

# Only delete the data folder if it is really ours (it contains a Containerfile).
if [ -f "$OC_HOME/Containerfile" ]; then
  rm -rf -- "$OC_HOME"
  echo "uninstall: removed $OC_HOME"
else
  echo "uninstall: $OC_HOME not found or not a sandbox folder, skipped"
fi

if [ "$PURGE" -eq 1 ]; then
  if command -v podman >/dev/null 2>&1; then
    podman rmi localhost/opencode-sandbox 2>/dev/null && echo "uninstall: image removed" || echo "uninstall: no image found"
    podman volume rm opencode-data 2>/dev/null && echo "uninstall: login volume removed" || echo "uninstall: no volume found"
  else
    echo "uninstall: podman not found, image and volume left untouched"
  fi
else
  echo "uninstall: image and login volume kept (use --purge to remove them)"
fi
