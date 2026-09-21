<!--
SPDX-FileCopyrightText: 2026 rickytheoldtree

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->

# Self-hosted deployment

This directory contains the server-side configuration used by the
`Deploy Self-Hosted` GitHub Actions workflow.

## Runtime layout

- The public account-enabled site is `https://game.r117.fun`.
- The account and save-data API is `https://api.r117.fun`; public Nginx proxies
  it to the loopback-only backend on `127.0.0.1:8001`.
- `/srv/pokerogue/releases/<commit-sha>` contains immutable releases.
- `/srv/pokerogue/current` points to the active release.
- `/srv/pokerogue/previous` points to the preceding release so that clients
  opened during a deployment can still load old hashed JavaScript and CSS.
- `pokerogue-web` serves the site on `127.0.0.1:8088` for the public reverse
  proxy. It is not directly exposed to the internet.

After the first release, rsync compares file checksums against `current` and
hard-links unchanged files into the new release. Each deployment remains an
independent snapshot without repeatedly transferring or storing unchanged game
assets.

The workflow builds with username/password accounts enabled and points the
client at `https://api.r117.fun`. OAuth buttons stay hidden until self-hosted
Discord or Google client IDs and server secrets are configured. Deployment
uses the unprivileged `pokerogue-deploy` account. GitHub Actions requires these
repository secrets:

- `DEPLOY_HOST`
- `DEPLOY_USER`
- `DEPLOY_SSH_KEY`
- `DEPLOY_KNOWN_HOSTS`

## Rollback

Releases are retained for the current version, the previous version, and up to
five recent release directories. To activate a retained release:

```bash
/srv/pokerogue/shared/deploy-release.sh \
  <40-character-commit-sha> \
  /srv/pokerogue/incoming/<40-character-commit-sha>.tar.gz
```

No archive is required when the matching release directory already exists.

## TLS renewal

The host `certbot.timer` is the sole renewal scheduler. Its configured webroot
`/var/www/certbot` points to the directory mounted by the public Nginx
container. After a successful renewal,
`/etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh` validates and reloads
the container. Do not add a second Certbot renewal loop to Compose.

The public Nginx container bind-mounts `nginx/nginx.conf` as a single file.
Update that file in place before running `nginx -t` and reloading. Replacing its
inode requires recreating the container before it can see the new file.
