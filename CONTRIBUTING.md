# Contributing

Thanks for wanting to help. This project is deliberately small: bash, one Containerfile, one config. Please keep it that way.

## Principles

- **Zero configuration first.** Defaults must be safe and work out of the box.
- **Safe by default.** Changes that loosen isolation need a clear reason and a note in `docs/SECURITY.md`.
- **Honest about limits.** Do not claim protection that does not exist.
- **Lightweight.** Target is a laptop with 4 GB of RAM. Avoid new dependencies.

## Running the tests

```bash
bash tests/smoke.sh
```

The tests use a fake `podman` and check the scripts' logic and the arguments passed to Podman. If available, also run:

```bash
shellcheck bin/oc install.sh uninstall.sh tests/smoke.sh
```

CI (GitHub Actions) runs both.

## Workflow

1. Fork and create a focused branch.
2. Change the code **and** add tests for new behaviour in `tests/smoke.sh`.
3. Update the documentation (`README.md`, `docs/`) when behaviour changes.
4. Add a note under `Unreleased` in `CHANGELOG.md`.
5. Open a pull request with a summary of the user-visible changes.

## Style

- Bash with `set -euo pipefail`; quote every variable.
- Short error messages, prefixed with `oc:` / `install:` / `uninstall:`.
- `oc`'s own commands are prefixed with `--oc-` so they never clash with `opencode` arguments.

## Most wanted

- Testing on various Fedora/Podman versions with SELinux enforcing (real tests, not the fake podman).
- Support for other distributions (Debian/Ubuntu, Arch) without breaking the Fedora defaults.
- `opencode.jsonc` presets for other stacks.
- Outbound network restriction (for example a proxy with a domain allowlist) as an option, not the default.
