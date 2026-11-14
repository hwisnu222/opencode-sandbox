# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

## 0.1.0

### Added
- The `oc` command to run OpenCode in a rootless Podman container.
- `container/Containerfile` (Node 22 slim, git, ripgrep, OpenCode, non-root user with UID 1000).
- `config/opencode.jsonc` with read/edit/bash rules and a test/lint/build allowlist.
- JSONC config with explanatory comments; `oc` validates it at startup and in `--oc-doctor`, and refuses to start if it does not parse.
- `install.sh` (no sudo; keeps a config the user has edited) and `uninstall.sh` (`--purge` for the image and volume).
- The `--oc-help`, `--oc-version`, `--oc-doctor`, `--oc-rebuild` and `--oc-shell` commands.
- The `OC_HOME`, `OC_PORTS`, `OC_MEMORY`, `OC_PIDS` and `OC_OPENCODE_VERSION` variables.
- Smoke tests based on a fake podman, and a CI workflow.
- Documentation: installation, usage, configuration, security, troubleshooting.
