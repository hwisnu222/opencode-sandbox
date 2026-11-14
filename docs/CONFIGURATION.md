# Configuration

## `oc` environment variables

| Variable | Default | Purpose |
|---|---|---|
| `OC_HOME` | `~/.local/share/opencode-sandbox` | Data folder (Containerfile, `opencode.jsonc`) |
| `OC_PORTS` | `3000` | Dev server ports exposed on `127.0.0.1`, space-separated |
| `OC_MEMORY` | `2g` | Container memory limit (`--memory` and `--memory-swap`) |
| `OC_PIDS` | `256` | Process count limit (`--pids-limit`) |
| `OC_OPENCODE_VERSION` | `latest` | `opencode-ai` version used when building the image |

To make them permanent, put them in `~/.bashrc`:

```bash
export OC_PORTS="3000 5173"
```

Do not raise `OC_MEMORY` above roughly 2.5 GB on a 4 GB laptop.

## `podman run` options used by `oc`

| Option | Purpose |
|---|---|
| `--userns=keep-id:uid=1000,gid=1000` | Maps the host user to the `agent` user in the container; files edited stay owned by you |
| `--cap-drop=ALL` | Drops all Linux capabilities |
| `--security-opt no-new-privileges` | Prevents processes from gaining privileges |
| `--memory` / `--memory-swap` | Memory limit, no extra swap |
| `--pids-limit` | Prevents fork bombs |
| `-v $PWD:/workspace:z` | The project folder; `:z` sets the SELinux label so access is not blocked |
| `-v opencode-data:...` | Named volume for login and sessions |
| `-v opencode.jsonc:...:ro,z` | Permission config, read-only |
| `-p 127.0.0.1:PORT:PORT` | Dev server ports, localhost only |

`--cpus` is intentionally not used: on rootless Podman the CPU limiter is not always delegated to the user and can cause errors.

`:z` relabels the mounted folder for SELinux. That is why `oc` refuses to run from `$HOME` or `/`.

## Permission config (`opencode.jsonc`)

This file is copied to `~/.local/share/opencode-sandbox/opencode.jsonc` and mounted read-only. Edit the **copy in the data folder** (not one inside a project), then run `oc` again. To change the default for everyone, edit `config/opencode.jsonc` in the repo and run `./install.sh --force-config`.

Structure:

| Section | Contents |
|---|---|
| `read` | `*` allowed; credential files (`.env`, keys, `.ssh`, `.aws`, ...) denied |
| `edit` | `*` allowed; credentials, `.git/hooks`, `.gitconfig` and shell dotfiles denied |
| `bash` | Default `ask`; read/test/lint/build allowed; dangerous commands denied |
| `external_directory` | `deny` |
| `webfetch` | `allow` |
| `skill` | Only the listed skills are allowed |

**Order matters:** the last matching rule wins. In `bash`, the `deny` rules for sensitive files come last so they override the allowed `cat *` or `grep *`. When adding rules, keep that pattern: general rules first, exceptions after.

Example of adding a test runner:

```json
"bash": {
  "*": "ask",
  "make test*": "allow",
  ...
}
```

Put it in the allow section, **before** the deny block. Avoid broad wildcards such as `npm run *`, `python *`, `node *`, or an unrestricted `find *` (`-exec` and `-delete`).

Validate the config after editing (comments and trailing commas are allowed). `oc` also refuses to start if the file does not parse:

```bash
oc --oc-doctor
```

Glob rules can differ between OpenCode versions. Test with a command that should be refused (for example `less .env`) to confirm the patterns work.

## Customizing the image

Edit `container/Containerfile` (or `~/.local/share/opencode-sandbox/Containerfile` for an existing install), add packages **before** the `USER agent` line, then run `oc --oc-rebuild`.

Python:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*
```

Go:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends golang-go \
    && rm -rf /var/lib/apt/lists/*
```

Build tools for native packages:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*
```

Running `./install.sh` again overwrites the Containerfile in the data folder with the repo version. Keep your changes in the repo (a fork) if you want them to be permanent.
