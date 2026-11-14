# opencode-sandbox

Run [OpenCode](https://opencode.ai) inside a **rootless Podman** container, so the AI agent can only touch your project folder, not your whole laptop (`~/.ssh`, `~/.aws`, personal documents, and so on).

Built for modest hardware (Fedora, 4 GB RAM): no daemon, no complicated configuration, one `oc` command.

```bash
git clone <this-repo-url> && cd opencode-sandbox
./install.sh
cd ~/path/to/project
oc auth login   # once
oc              # start OpenCode, isolated
```

## Why this exists

AI agents run shell commands, install packages and read files. Allow/deny rules inside the agent are only text-pattern matching and can be bypassed. This repo gives you two layers:

| Layer | Purpose | Nature |
|---|---|---|
| **Rootless Podman container** | The agent physically sees only the project folder | Hard boundary |
| **`config/opencode.jsonc`** | Allow/ask/deny rules for files and commands | Soft boundary, reduces mistakes and prompts |

```
Host (Fedora)                         Podman container (rootless)
-----------------------------         ------------------------------------
~/projects/my-app  ---- mount ----->  /workspace   (readable and writable)
opencode.jsonc (read-only)  -------->  permission config
volume opencode-data  ------------->  OpenCode login and sessions
~/.ssh, ~/.aws, etc.                  NOT VISIBLE from the container
```

## Features

- A single `oc` command; any argument is passed through to `opencode` (`oc auth login`, `oc --continue`, ...).
- Rootless, `--cap-drop=ALL`, `no-new-privileges`, memory and process limits.
- Files edited by the agent stay owned by the host user (`--userns=keep-id`).
- The permission config is mounted **read-only** at OpenCode's global config path, so the agent cannot edit that file. OpenCode also merges a project-level `opencode.jsonc` on top of it (see [Security](docs/SECURITY.md)).
- The config is JSONC (`opencode.jsonc`, with explanatory comments). `oc` validates it at startup and refuses to run if it does not parse.
- Refuses to run from `$HOME` or `/` (prevents mounting your entire home).
- The image is built automatically when missing; `oc --oc-rebuild` updates it.
- Dev server ports are exposed on `127.0.0.1` only.
- Your git identity (name and email only) is forwarded so the agent can `git commit`. No credentials, so `git push` from inside the container is impossible.
- Environment check: `oc --oc-doctor`.

## Requirements

- Linux with Podman 4.3 or newer (rootless). Designed and written for Fedora with SELinux.
- `bash`, `git`.
- Internet access to build the image and reach the model API.
- About 1 GB of disk.

## Commands

| Command | Purpose |
|---|---|
| `oc` | Start OpenCode in the current folder |
| `oc auth login` | Log in to a model provider (stored in the `opencode-data` volume) |
| `oc --oc-doctor` | Check Podman, config, image, subuid and PATH |
| `oc --oc-rebuild` | Rebuild the image without cache (latest OpenCode) |
| `oc --oc-shell` | Bash shell in the same container |
| `oc --oc-help` / `--oc-version` | Help / version |

Environment variables: `OC_PORTS`, `OC_MEMORY`, `OC_PIDS`, `OC_OPENCODE_VERSION`, `OC_HOME`. Example:

```bash
OC_PORTS="3000 5173" OC_MEMORY=2g oc
```

## Documentation

- [Installation](docs/INSTALL.md)
- [Usage for development](docs/USAGE.md)
- [Configuration](docs/CONFIGURATION.md)
- [Security: what is and is not protected](docs/SECURITY.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)

## Limitations (read this)

- The container shares the host kernel. Rootless Podman reduces the impact of an escape, but it is not as strong as a VM. For genuinely untrusted code, use a VM.
- The agent can still delete or damage the contents of the project folder. Use git and branches.
- Outbound network access is not restricted. Data in your project can be sent out if you approve a command such as `curl`.
- The OpenCode login/API key lives inside the container and can be read by the agent.
- `.env` files inside the project are visible to the agent. The config only blocks reading them through pattern rules, not through isolation.

Full details in [docs/SECURITY.md](docs/SECURITY.md).

## Testing status

The automated tests (`bash tests/smoke.sh`) use a fake `podman` to check the scripts' logic and the arguments passed to Podman. They do **not** run a real container. Real-world behaviour (SELinux, cgroups, UID mapping, image build) has not been tested across Fedora/Podman versions. Please report problems through an issue and include the output of `oc --oc-doctor`.

## License

MIT. See [LICENSE](LICENSE).
