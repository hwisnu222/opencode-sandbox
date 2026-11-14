# Troubleshooting

Start with:

```bash
oc --oc-doctor
```

## `oc: command not found`

`~/.local/bin` is not on your PATH. See [INSTALL.md](INSTALL.md#4-make-sure-localbin-is-on-your-path), then open a new terminal.

## "run this from a project folder, not from your home directory or /"

This is intentional. If `$HOME` were mounted, everything in your home would be visible to the agent and `:z` would relabel your entire home for SELinux. Change into the project folder first.

## "Permission denied" on `/workspace`

- Make sure you are running from the right project folder.
- Check the SELinux label: `ls -Z` on the project folder. `oc` uses `:z` so the label is set automatically.
- Check ownership: `ls -ld .` should show your user.

## "podman is too old, 4.3 or newer is required"

The `--userns=keep-id:uid=,gid=` option only exists from Podman 4.3. Update: `sudo dnf upgrade podman`.

## Files edited by the agent have a strange owner UID

Check `ls -ln` on the file and `id -u`. `keep-id:uid=1000,gid=1000` maps your UID to 1000 inside the container whatever your real UID is. If it is still wrong, send the output of `ls -ln` and `podman --version`.

## subuid not registered

```bash
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
podman system migrate
```

## Memory or cgroup errors

Usually the cgroup controllers are not delegated to your user session. Check:

```bash
cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/cgroup.controllers
```

`memory` and `pids` must be present. If they are not, run Podman manually without `--memory`/`--pids-limit` to confirm the problem is there. Afterwards, delegate the controllers through systemd (`Delegate=` on `user@.service`), or continue without limits while being aware of the risk.

## The container dies suddenly (out of memory)

Raise `OC_MEMORY` slightly (at most about 2.5g on a 4 GB laptop) or reduce the load: do not run builds in parallel and limit the Node heap (`NODE_OPTIONS=--max-old-space-size=1024`).

## Image build fails (`apt-get` or `npm install`)

- Check your internet connection and DNS.
- Retry with `oc --oc-rebuild`.
- The base image uses the `docker.io/library/` prefix so Podman does not ask which registry to use.

## Login is lost every session

The `opencode-data` volume is not mounted or was removed. Check `podman volume ls`. If necessary, log in again: `oc auth login`.

## The dev server cannot be opened in the host browser

- The server must bind to `0.0.0.0`, not `localhost` (see [USAGE.md](USAGE.md#dev-servers)).
- The port must be listed in `OC_PORTS`.
- Check that no other process is using the port: `ss -ltnp | grep 3000`.

## "config is not valid JSONC"

The config file has a syntax error. `oc` refuses to start with it, so a broken file can never silently leave you without your permission rules. Fix the file (a missing comma or quote is typical) and run `oc --oc-doctor`. Comments (`//`, `/* */`) and trailing commas are allowed.

## The permission config does not apply

- Make sure the file exists: `~/.local/share/opencode-sandbox/opencode.jsonc`.
- Check that no other config in the project folder overrides it.
- Test with a command that should be refused (for example `less .env`).
- Validate the syntax: `oc --oc-doctor` (JSONC, so comments and trailing commas are fine).

## `opencode.jsonc.new` appeared in the data folder

`install.sh` keeps a config you have already edited and saves the new version as `.new`. Compare them with `diff`, merge what you need, or run `./install.sh --force-config` to overwrite.

## Reporting a bug

Include: the output of `oc --oc-doctor`, `podman --version`, your Fedora version (`cat /etc/fedora-release`), and the full error message.
