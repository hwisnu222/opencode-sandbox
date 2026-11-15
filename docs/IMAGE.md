# Derived images

The base `opencode-sandbox` image is deliberately small: Node, git, ripgrep, and OpenCode. If a project needs an extra toolchain (Python, Go, Rust, and so on), don't install it inside a running container. Build a **derived image** on top of the base image instead.

## Why not install inside the running container

- The container runs as the non-root `agent` user with `--cap-drop=ALL` and `no-new-privileges`, so `apt install` is refused. This is intentional.
- The container uses `--rm`, so anything installed is lost when it exits.
- An image built once is always the same; installing at runtime can differ from session to session.

## What goes in the image and what doesn't

| Kind                 | Examples                               | Where it lives                                           |
| -------------------- | -------------------------------------- | -------------------------------------------------------- |
| System tools         | `python3`, `golang`, `build-essential` | The image (build time)                                   |
| Project dependencies | `node_modules`, `.venv`, `vendor/`     | The project folder on the host (mounted at `/workspace`) |

Project dependencies are still installed inside the project folder, for example `npm install` or `python3 -m venv .venv`. They are stored on the host, so they persist and don't belong in the image.

## Prerequisite: the `OC_IMAGE` variable

`oc` 0.1.0 always uses the image `localhost/opencode-sandbox` and has no variable to override it. Add one line to `bin/oc`.

Replace:

```bash
IMAGE="localhost/${IMAGE_NAME}"
```

with:

```bash
IMAGE="${OC_IMAGE:-localhost/${IMAGE_NAME}}"
```

This only affects the image that is run (`oc`, `--oc-shell`, `--oc-doctor`). `oc --oc-rebuild` still builds the base image.

Until that change is applied, the steps below can't be used through `oc`.

## Example: a project that needs Python

### 1. Write the derived Containerfile

Save it as `Containerfile.python` (in any folder, for example `~/.local/share/opencode-sandbox/`):

```dockerfile
FROM localhost/opencode-sandbox

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*
USER agent
```

Both `USER` lines are required. The base image ends with `USER agent`, so you switch to root only during the build and then switch back. The running container is still non-root.

### 2. Build

```bash
podman build -t opencode-sandbox-python -f Containerfile.python .
```

### 3. Run

```bash
cd ~/project
OC_IMAGE=localhost/opencode-sandbox-python oc
```

To avoid typing it every time, add an alias:

```bash
alias oc-py='OC_IMAGE=localhost/opencode-sandbox-python oc'
```

### 4. Use a venv in the project folder

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python app.py
```

A global `pip install` (without a venv) fails because `agent` cannot write to system directories. Use a venv.

## Updating

A derived image does **not** change when you run `oc --oc-rebuild`. The order is:

```bash
oc --oc-rebuild                                                      # refresh the base image
podman build -t opencode-sandbox-python -f Containerfile.python .   # rebuild the derived image
```

If you reverse the order, the derived image is still built on the old base image.

## Removing

```bash
podman rmi opencode-sandbox-python
```

Derived images use disk space. On a laptop with limited disk, don't create one image per project; a single image with a few tools is usually enough.

## Security

- A derived image does **not** change the runtime restrictions. `--cap-drop=ALL`, `no-new-privileges`, the memory limit, and the read-only config mount are still applied by `oc` at `podman run` time.
- Permission rules still apply. Installing `python3` does not make `python* -c *` automatically allowed; in the default config it stays `ask`.
- Install only the packages you actually use. Every package adds image size and attack surface.
- Only build Containerfiles you wrote or reviewed yourself. Don't run `podman build` on a Containerfile from a cloned project without reading it first, because its `RUN` commands execute at build time.
