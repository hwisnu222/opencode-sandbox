# Usage for development

## Daily workflow

```bash
cd ~/projects/my-app
git switch -c feature/my-feature   # branch first
oc                                 # give the agent a task
git diff                           # review on the host
git add -p && git commit           # commit from the host
git push                           # push from the host
```

Inside the session the agent works in `/workspace`, which is your project folder. Changes show up on the host immediately, so an editor on the host can stay open alongside.

Isolation protects the host, **not the project itself**. The agent can delete or damage the project contents. Commit or branch before a session, and discard bad results with `git restore .`.

## Git inside the container

`oc` forwards `user.name` and `user.email` from the host's git so the agent can `git commit`. Credentials are not forwarded, so `git push` from inside the container is impossible (by design). The agent or you may commit; push always happens from the host.

## Dev servers

Container ports are mapped to `127.0.0.1` on the host. Only 3000 by default. For other ports:

```bash
OC_PORTS="3000 5173 8000" oc
```

The dev server **must listen on `0.0.0.0` inside the container**, not `localhost`:

| Framework | Command |
|---|---|
| Vite | `npm run dev -- --host 0.0.0.0 --port 5173` |
| Next.js | `npx next dev -H 0.0.0.0 -p 3000` |
| Express/Node | `app.listen(3000, '0.0.0.0')` |
| Python | `python3 -m http.server 8000 --bind 0.0.0.0` |

Then open `http://localhost:<port>` in the host browser.

## Dependencies

The image contains Node.js 22, git and ripgrep. A `node_modules` folder from a Linux x86_64 host is usually compatible. If a native package misbehaves, delete `node_modules` and reinstall where it will be used. For Python, Go or build tools, see [CONFIGURATION.md](CONFIGURATION.md#customizing-the-image).

## Tests, lint and build without prompts

`config/opencode.jsonc` allows these commands so they do not ask for confirmation:

```
npm test | npm run test | npm run lint | npm run build | npm run typecheck
npx tsc | npx eslint | npx prettier
pnpm test | pnpm lint
pytest | ruff
go test | go vet
cargo test | cargo check | cargo clippy
```

Other commands ask for confirmation. Add safe, frequently used ones to the config (see [CONFIGURATION.md](CONFIGURATION.md)). Avoid wildcards such as `npm run *` or `python *`, because they amount to allowing everything.

## A shell in the container

```bash
oc --oc-shell
```

The same environment as an OpenCode session, handy for trying commands by hand.

## One session at a time

Every `oc` creates a new container. With 4 GB of RAM, run one session at a time. The memory limit per container is 2 GB (change it with `OC_MEMORY`).

## RAM-saving tips

- Limit the Node heap if a build runs out of memory: `oc --oc-shell`, then `NODE_OPTIONS=--max-old-space-size=1024 npm run build`.
- Run tests and builds one at a time, not in parallel.
- Close heavy browsers during large builds.
- Fedora enables zram by default; check with `zramctl`.

## Backing up your login

Your OpenCode login and sessions live in the Podman volume `opencode-data`.

```bash
podman volume export opencode-data -o ~/opencode-data-backup.tar
```

Restore:

```bash
podman volume create opencode-data
podman volume import opencode-data ~/opencode-data-backup.tar
```

Reset the login: `podman volume rm opencode-data`, then `oc auth login`.

## Maintenance

```bash
podman system df          # disk usage
podman image prune        # remove dangling images after a rebuild
```
