# Installation

Target: Fedora (LXQt or any other), rootless Podman. Every step runs without `sudo`, except installing Podman itself.

## 1. Install Podman

```bash
sudo dnf install -y podman
podman --version        # 4.3 or newer is required
```

## 2. Make sure rootless mode is ready

Rootless Podman needs subuid/subgid ranges for your user. On Fedora this is usually automatic:

```bash
grep "^$USER:" /etc/subuid /etc/subgid
```

There must be a line in both files. If they are empty:

```bash
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
podman system migrate
```

Test Podman:

```bash
podman run --rm docker.io/library/hello-world
```

## 3. Install

```bash
git clone <this-repo-url>
cd opencode-sandbox
./install.sh
```

What `install.sh` does:

| Step | Result |
|---|---|
| Copies `container/Containerfile` | `~/.local/share/opencode-sandbox/Containerfile` |
| Copies `config/opencode.jsonc` | `~/.local/share/opencode-sandbox/opencode.jsonc` |
| Copies `bin/oc` | `~/.local/bin/oc` |
| Builds the image | `localhost/opencode-sandbox` (a few minutes) |

Options:

| Option | Purpose |
|---|---|
| `--no-build` | Skip building the image. Build it later with `oc --oc-rebuild` (or automatically the first time you run `oc`). |
| `--force-config` | Overwrite an existing `opencode.jsonc`. Without it, a config you already edited is kept and the new version is saved as `opencode.jsonc.new`. |

Locations can be changed with the `OC_HOME` (data) and `BIN_DIR` (command) variables.

## 4. Make sure `~/.local/bin` is on your PATH

Fedora usually includes it already. Check:

```bash
echo "$PATH" | tr ':' '\n' | grep local/bin
```

If nothing shows up:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 5. Check and log in

```bash
oc --oc-doctor
cd ~/path/to/project
oc auth login
oc
```

`oc --oc-doctor` checks Podman, its version, the config, the Containerfile, the image, subuid and PATH. Every line should read `[ok]`.

## Updating

```bash
cd opencode-sandbox
git pull
./install.sh            # refresh the scripts, Containerfile and image
```

To update only OpenCode to the latest version: `oc --oc-rebuild`. For a specific version: `OC_OPENCODE_VERSION=1.2.3 oc --oc-rebuild`.

## Uninstalling

```bash
./uninstall.sh            # remove oc and the data folder; image and login are kept
./uninstall.sh --purge    # also remove the image and the login volume
```

Back up your login before `--purge` if needed (see [USAGE.md](USAGE.md#backing-up-your-login)).
