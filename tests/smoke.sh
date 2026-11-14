#!/usr/bin/env bash
# Smoke tests for oc, install.sh and uninstall.sh using a fake podman.
# No real Podman needed. Run:  bash tests/smoke.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
check() { # check "description" command...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}

# --- fake podman: logs its arguments; behaviour is driven by variables ---
FAKEBIN="$TMP/fakebin"
mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/podman" <<'FAKE'
#!/usr/bin/env bash
echo "$@" >> "$FAKE_PODMAN_LOG"
case "$1" in
  --version) echo "podman version ${FAKE_PODMAN_VERSION:-5.0.0}" ;;
  image) [ "${FAKE_IMAGE_EXISTS:-1}" = "1" ] ;;
  rmi|volume|build|run) exit 0 ;;
esac
FAKE
chmod +x "$FAKEBIN/podman"

export FAKE_PODMAN_LOG="$TMP/podman.log"
export HOME="$TMP/home"
mkdir -p "$HOME/.local/bin" "$HOME/proj"
export PATH="$FAKEBIN:$PATH"
export OC_HOME="$TMP/data"
export BIN_DIR="$HOME/.local/bin"
export XDG_DATA_HOME="$TMP/xdg"
unset OC_PORTS OC_MEMORY OC_PIDS OC_OPENCODE_VERSION

echo "== syntax"
for f in bin/oc install.sh uninstall.sh tests/smoke.sh; do
  check "bash -n $f" bash -n "$REPO/$f"
done
mkdir -p "$TMP/cfgcheck" && cp "$REPO/config/opencode.jsonc" "$TMP/cfgcheck/opencode.jsonc"
check "config/opencode.jsonc is valid JSONC" bash -c "OC_HOME='$TMP/cfgcheck' bash '$REPO/bin/oc' --oc-doctor | grep -q 'config is valid JSONC'"

echo "== install.sh"
: > "$FAKE_PODMAN_LOG"
bash "$REPO/install.sh" --no-build >"$TMP/install.out" 2>&1
check "install --no-build succeeds" test -x "$BIN_DIR/oc"
check "Containerfile installed" test -f "$OC_HOME/Containerfile"
check "opencode.jsonc installed" test -f "$OC_HOME/opencode.jsonc"
check "install --no-build does not call podman build" bash -c "! grep -q '^build' '$FAKE_PODMAN_LOG'"

echo "x" > "$OC_HOME/opencode.jsonc"
bash "$REPO/install.sh" --no-build >"$TMP/install2.out" 2>&1
check "user-edited config is kept" bash -c "[ \"\$(cat '$OC_HOME/opencode.jsonc')\" = x ]"
check "new version saved as .new" test -f "$OC_HOME/opencode.jsonc.new"
bash "$REPO/install.sh" --no-build --force-config >/dev/null 2>&1
check "--force-config overwrites the config" cmp -s "$REPO/config/opencode.jsonc" "$OC_HOME/opencode.jsonc"

: > "$FAKE_PODMAN_LOG"
bash "$REPO/install.sh" >/dev/null 2>&1
check "full install calls podman build --no-cache" grep -q "^build .*--no-cache" "$FAKE_PODMAN_LOG"

check "install rejects unknown arguments" bash -c "! bash '$REPO/install.sh' --bogus"

echo "== oc: help and version"
OC="$BIN_DIR/oc"
check "--oc-version" bash -c "'$OC' --oc-version | grep -q '^oc '"
check "--oc-help" bash -c "'$OC' --oc-help | grep -q 'oc --oc-doctor'"
check "--oc-help does not leak code" bash -c "! '$OC' --oc-help | grep -q 'set -euo'"
check "--oc-help lists all variables" bash -c "'$OC' --oc-help | grep -q 'OC_OPENCODE_VERSION'"
check "install --help does not leak code" bash -c "! bash '$REPO/install.sh' --help | grep -q 'set -euo'"
check "uninstall --help does not leak code" bash -c "! bash '$REPO/uninstall.sh' --help | grep -q 'set -euo'"

echo "== oc: validation"
cd "$HOME" || exit 1
check "refuses to run from HOME" bash -c "! '$OC'"
cd "$HOME/proj" || exit 1

: > "$FAKE_PODMAN_LOG"
check "rejects podman < 4.3" bash -c "! FAKE_PODMAN_VERSION=4.2.1 '$OC'"
check "accepts podman 4.3" bash -c "FAKE_PODMAN_VERSION=4.3.0 '$OC'"
check "accepts podman 4.9" bash -c "FAKE_PODMAN_VERSION=4.9.4 '$OC'"
check "accepts podman 5.x" bash -c "FAKE_PODMAN_VERSION=5.2.1 '$OC'"

check "rejects non-numeric port" bash -c "! OC_PORTS='abc' '$OC'"
check "rejects port 0" bash -c "! OC_PORTS='0' '$OC'"
check "rejects port > 65535" bash -c "! OC_PORTS='70000' '$OC'"

mv "$OC_HOME/opencode.jsonc" "$OC_HOME/opencode.jsonc.bak"
check "fails when the config is missing" bash -c "! '$OC'"
mv "$OC_HOME/opencode.jsonc.bak" "$OC_HOME/opencode.jsonc"

cp "$OC_HOME/opencode.jsonc" "$OC_HOME/opencode.jsonc.bak"
printf '{ "broken": ' > "$OC_HOME/opencode.jsonc"
: > "$FAKE_PODMAN_LOG"
check "refuses to start with an invalid config" bash -c "! '$OC'"
check "an invalid config never reaches podman run" bash -c "! grep -q '^run ' '$FAKE_PODMAN_LOG'"
mv "$OC_HOME/opencode.jsonc.bak" "$OC_HOME/opencode.jsonc"

echo "== oc: JSONC validation"
mkdir -p "$TMP/jc"
doctor_says() { # doctor_says <config content> <expected text>
  printf '%s\n' "$1" > "$TMP/jc/opencode.jsonc"
  local out
  out="$(OC_HOME="$TMP/jc" bash "$REPO/bin/oc" --oc-doctor 2>&1 || true)"
  grep -q -- "$2" <<< "$out"
}
check "JSONC: comments, trailing commas and // inside strings are accepted" \
  doctor_says $'// c\n{ "u": "http://x/y", /* b */ "k": [1, 2,], }' "config is valid JSONC"
check "JSONC: truncated JSON is rejected" doctor_says '{ "a": ' "config is not valid JSONC"
check "JSONC: unterminated block comment is rejected" doctor_says $'{ "a": 1 /* oops }' "config is not valid JSONC"
check "JSONC: a plain JSON file is still accepted" doctor_says '{ "a": [1, 2] }' "config is valid JSONC"

echo "== oc: podman run arguments"
: > "$FAKE_PODMAN_LOG"
"$OC" auth login >/dev/null 2>&1
RUNLINE="$(grep '^run ' "$FAKE_PODMAN_LOG" | tail -1)"
for needle in \
  "--userns=keep-id:uid=1000,gid=1000" \
  "--cap-drop=ALL" \
  "--security-opt no-new-privileges" \
  "--memory 2g" \
  "--memory-swap 2g" \
  "--pids-limit 256" \
  "$HOME/proj:/workspace:z" \
  "opencode-data:/home/agent/.local/share/opencode" \
  "/home/agent/.config/opencode/opencode.jsonc:ro,z" \
  "-p 127.0.0.1:3000:3000" \
  "localhost/opencode-sandbox opencode auth login"; do
  if printf '%s' "$RUNLINE" | grep -qF -- "$needle"; then pass "run contains: $needle"; else fail "run contains: $needle"; fi
done
check "does not contain --privileged" bash -c "! printf '%s' '$RUNLINE' | grep -q -- '--privileged'"
check "does not mount the home directory" bash -c "! printf '%s' '$RUNLINE' | grep -qF -- '-v $HOME:'"

: > "$FAKE_PODMAN_LOG"
OC_PORTS="3000 5173" OC_MEMORY=1g OC_PIDS=64 "$OC" >/dev/null 2>&1
RUNLINE="$(grep '^run ' "$FAKE_PODMAN_LOG" | tail -1)"
for needle in "-p 127.0.0.1:3000:3000" "-p 127.0.0.1:5173:5173" "--memory 1g" "--pids-limit 64"; do
  if printf '%s' "$RUNLINE" | grep -qF -- "$needle"; then pass "override contains: $needle"; else fail "override contains: $needle"; fi
done

echo "== oc: git identity"
GIT_CONFIG_GLOBAL="$TMP/gitconfig" git config --global user.name "Budi Test"
GIT_CONFIG_GLOBAL="$TMP/gitconfig" git config --global user.email "budi@example.test"
: > "$FAKE_PODMAN_LOG"
GIT_CONFIG_GLOBAL="$TMP/gitconfig" "$OC" >/dev/null 2>&1
RUNLINE="$(grep '^run ' "$FAKE_PODMAN_LOG" | tail -1)"
if printf '%s' "$RUNLINE" | grep -qF "GIT_AUTHOR_EMAIL=budi@example.test"; then pass "git email is forwarded"; else fail "git email is forwarded"; fi
if printf '%s' "$RUNLINE" | grep -qF "GIT_AUTHOR_NAME=Budi Test"; then pass "git name is forwarded"; else fail "git name is forwarded"; fi

echo "== oc: auto build, rebuild, shell"
: > "$FAKE_PODMAN_LOG"
FAKE_IMAGE_EXISTS=0 "$OC" >/dev/null 2>&1
check "missing image -> automatic build" grep -q "^build " "$FAKE_PODMAN_LOG"
: > "$FAKE_PODMAN_LOG"
OC_OPENCODE_VERSION=1.2.3 "$OC" --oc-rebuild >/dev/null 2>&1
check "--oc-rebuild uses --no-cache" grep -q "^build .*--no-cache" "$FAKE_PODMAN_LOG"
check "--oc-rebuild forwards the opencode version" grep -q "OPENCODE_VERSION=1.2.3" "$FAKE_PODMAN_LOG"
: > "$FAKE_PODMAN_LOG"
"$OC" --oc-shell >/dev/null 2>&1
check "--oc-shell runs bash" grep -q "localhost/opencode-sandbox bash" "$FAKE_PODMAN_LOG"

echo "== oc: doctor"
check "--oc-doctor works with the fake podman" bash -c "FAKE_PODMAN_VERSION=5.0.0 '$OC' --oc-doctor | grep -q 'podman version >= 4.3'"
check "--oc-doctor fails when the image is missing" bash -c "! FAKE_IMAGE_EXISTS=0 '$OC' --oc-doctor"

echo "== uninstall.sh"
cd "$REPO" || exit 1
: > "$FAKE_PODMAN_LOG"
bash "$REPO/uninstall.sh" >/dev/null 2>&1
check "oc is removed" bash -c "! [ -e '$BIN_DIR/oc' ]"
check "data folder is removed" bash -c "! [ -e '$OC_HOME' ]"
check "without --purge the image is untouched" bash -c "! grep -q '^rmi' '$FAKE_PODMAN_LOG'"

mkdir -p "$TMP/not-a-sandbox"
echo keep > "$TMP/not-a-sandbox/important.txt"
OC_HOME="$TMP/not-a-sandbox" bash "$REPO/uninstall.sh" >/dev/null 2>&1
check "does not delete a folder that is not ours" test -f "$TMP/not-a-sandbox/important.txt"

: > "$FAKE_PODMAN_LOG"
bash "$REPO/uninstall.sh" --purge >/dev/null 2>&1
check "--purge removes the image" grep -q "^rmi" "$FAKE_PODMAN_LOG"
check "--purge removes the volume" grep -q "^volume rm" "$FAKE_PODMAN_LOG"

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
