# Security

This document is honest about what is and is not protected. This repo reduces risk; it does not remove it.

## Threat model

The assumption: you run an AI agent on **your own project** and want to prevent leaks or damage outside it caused by agent mistakes, mild prompt injection, or commands that go too far. This is not a sandbox for malicious code deliberately written to escape a container.

## What is protected

- **Host files outside the project folder**: `~/.ssh`, `~/.aws`, `~/.gnupg`, personal documents and so on are not mounted, so from the agent's point of view they do not exist.
- **The global permission config**: mounted read-only; the agent cannot edit that file.
- **The host from runaway processes**: memory and process-count limits.
- **Privileges**: rootless, all capabilities dropped, `no-new-privileges`. If something escapes the container, it lands in a regular user account, not root.
- **Git credentials**: only name and email are forwarded. `git push` from the container is impossible.
- **Ports**: dev servers are exposed on `127.0.0.1` only, not on your Wi-Fi network.

## What is not protected

| Risk | Explanation | Mitigation |
|---|---|---|
| **Project contents** | The agent can delete or change anything in `/workspace` | Commit/branch before a session; review `git diff` |
| **Secrets inside the project** | `.env` in the project is visible to the agent; `deny` rules are only text patterns | Do not keep production secrets in the project folder; work on a copy without secrets |
| **Outbound network** | The container can reach the internet; a `curl` you approve can send project data out | Keep `curl`/`wget` on `ask`; read every command before approving |
| **Model credentials** | The OpenCode login lives in the `opencode-data` volume and can be read by the agent | Use tokens with usage limits; rotate if you suspect misuse |
| **Project-level config** | OpenCode merges an `opencode.jsonc` or `.opencode/` folder found in the project on top of the global config, and project files take precedence. The agent can edit them, and a cloned repo may ship one that loosens permissions | Review those files before running `oc`; consider adding `edit` deny rules for them |
| **Kernel/container exploits** | The container shares the host kernel | For untrusted code, use a VM |
| **Docker/Podman socket** | If you add a socket mount to the container, the agent gets control of the host | Never mount the socket |

## About the rules in `opencode.jsonc`

String pattern matching is easy to bypass. For example, a rule for `cat .env` does not catch `python3 -c "print(open('.env').read())"`. That is why:

- Inline interpreters (`python -c`, `node -e`, `bash -c`) are set to `ask`.
- The bash deny rules are generic (`*.env*`), not per command.
- The container remains the hard boundary; the rules are only a second layer.

Because every prompt has an "allow" button, risk also comes from carelessness: do not approve commands you do not understand.

## Recommended practice

1. Commit or branch before an agent session.
2. Review `git diff` before committing and pushing.
3. Do not run `oc` from `$HOME` or from a folder containing many projects (`oc` refuses `$HOME` and `/`, but other parent folders are still possible).
4. Do not mount `~/.ssh`, `~/.aws`, or the Podman/Docker socket.
5. Read every command that asks for confirmation, especially network ones.
6. Update the image regularly (`oc --oc-rebuild`).
7. For foreign or untrusted repos, do not use this tool; use a VM.

## Reporting security issues

Open a private issue or contact the maintainers directly; do not put exploit details in a public issue.
