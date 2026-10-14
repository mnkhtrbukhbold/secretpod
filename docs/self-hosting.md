# Self-host SecretPod

Docker Compose is the primary deployment path. One prebuilt SecretPod image contains the Flutter website and Serverpod API. Caddy supplies HTTPS. SQLite, the master key and certificates persist separately from application containers. No Flutter, Dart, PostgreSQL, Redis or cloud account is required on the host.

## Requirements

- A Linux server with Docker Engine and Compose v2, Python 3.10+, curl and tar. The first release image targets Linux amd64. Docker Desktop can run it on Windows/macOS; ARM hosts need amd64 emulation.
- For public HTTPS, a hostname whose A/AAAA records point to this server, reachable TCP ports 80 and 443, and outbound access for pulling images and obtaining certificates. Remove incorrect AAAA records. Caddy obtains and renews publicly trusted certificates automatically when these conditions hold.
- Local persistent disk. Run one app instance per vault. Do not mount SQLite on network storage or scale the app service to multiple replicas.
- On Windows, install Python from python.org and disable the Microsoft Store execution alias if it intercepts `python`.

## One-command public installation

After prerequisites and DNS are configured, replace the hostname:

```sh
curl -fsSL https://raw.githubusercontent.com/mnkhtrbukhbold/secretpod/v0.1.0/scripts/install.sh | sh -s -- --url https://vault.example.com
```

The bootstrap downloads the tagged source tools, pulls `ghcr.io/mnkhtrbukhbold/secretpod:0.1.0`, creates `~/secretpod`, generates the master key once, and starts Compose. Open your HTTPS URL and create an account. There are no default credentials. Registration is currently open to anyone who can reach the instance; use your network access controls for a private team installation.

If the official registry image cannot be pulled anonymously, setup downloads the identical prebuilt image from the public GitHub Release, verifies its SHA-256 checksum and loads it into Docker. It does not fall back to compiling source. Release archives also provide an offline distribution format.

To inspect the installer before executing, download the tagged repository archive, extract it, and run:

```sh
sh scripts/setup.sh --url https://vault.example.com --dir "$HOME/secretpod"
```

Windows, from the extracted source directory:

```powershell
.\scripts\setup.ps1 --url https://vault.example.com --dir "$HOME\secretpod"
```

Rerunning setup for the same installation preserves its project identity, key and data. It refuses a different image or URL and refuses to generate a replacement key for an existing installation. A failed initial pull can be retried with the same command. A partially created installation is not silently adopted.

## Local HTTPS

Use `https://localhost` for a local evaluation, or custom ports if 80/443 are occupied:

```sh
sh scripts/setup.sh --url https://localhost:8443 --http-port 8088
python3 "$HOME/secretpod/scripts/host.py" trust-cert --dir "$HOME/secretpod"
```

Localhost binds only to loopback. Caddy issues a local certificate; it is not publicly trusted. The second command exports `~/secretpod/local-root.crt`. Import that root certificate into the client machine/browser's trust store to trust this local installation. This command does not change system trust automatically. Public hostnames use ACME instead.

## What is stored where

The installation directory is private (0700 on POSIX; an explicit current-user/SYSTEM ACL on Windows). It contains:

| Path | Purpose |
| --- | --- |
| `secrets/master_key` | The generated encryption key, mounted read-only into the unprivileged app |
| `manifest.json` | Image version, public origin, ports and unique Compose project identity |
| `config.env` | Non-secret Compose settings |
| `compose.yaml`, `Caddyfile` | Installed deployment configuration |
| `scripts/host.py` | Retained management command; source download is no longer required |
| `backups/` | Backups automatically created before upgrades |

The named `<project>_vault-data` volume holds the SQLite database. Caddy certificate state is in `<project>_caddy-data`; its internal configuration is in `<project>_caddy-config`. Container recreation preserves these volumes. Do not use `docker compose down -v` on an installation you intend to keep.

Keep the installation directory and backup directories private. The key file is readable inside the container but protected on the host by its parent directory. Losing the matching master key makes encrypted values unrecoverable. The operator can decrypt secrets; this is encryption at rest, not zero-knowledge encryption.

## Runtime routing

Only Caddy publishes ports. `/api/` is forwarded to the app's private API port 8080 with the prefix removed; the website goes to private port 8082. `/app-config.json` supplies the browser's API URL at runtime and is never cached. The image is identical for every hostname. Production requires an HTTPS public origin and rejects API requests carrying a different browser Origin. Health checks use `/healthz` after the vault has initialized.

`SECRETPOD_PUBLIC_URL` and `SECRETPOD_API_URL` are public configuration. `SECRETPOD_MASTER_KEY_FILE` points to the read-only key file. Direct key environment variables remain available for source development, but combining a key file and a key environment variable is rejected. None belongs in a Docker build argument.

## Daily operations

Use `python` instead of `python3` on Windows. These examples assume the default installation location:

```sh
python3 "$HOME/secretpod/scripts/host.py" status --dir "$HOME/secretpod"
python3 "$HOME/secretpod/scripts/host.py" stop --dir "$HOME/secretpod"
python3 "$HOME/secretpod/scripts/host.py" up --dir "$HOME/secretpod"
```

Operations on the same installation are serialized. After a crashed management process, a lock can remain; verify that no management process is still running before removing the lock named in the error. Never remove locks to run operations concurrently.

## Backup

```sh
python3 "$HOME/secretpod/scripts/host.py" backup --dir "$HOME/secretpod" --backup "$HOME/secretpod-backup-2026-10-14"
```

The destination must not already exist. Backup stops the app, archives the complete data volume, saves its matching key and manifest, writes SHA-256 checksums, verifies the archive, and resumes the app if it was running. This causes brief downtime. Never copy only a running SQLite main file.

The backup contains both ciphertext and its decryption key. It is a private directory, not an encrypted export: store it on protected or encrypted backup storage. Checksums detect corruption, not malicious modification. Treat restore input as a trusted backup.

## Restore and move to another host

Copy the complete backup directory to the destination machine. Use the management script from a source download or the retained installation. Restore into a directory that does not exist:

```sh
python3 scripts/host.py restore --dir "$HOME/secretpod-restored" --backup "$HOME/secretpod-backup-2026-10-14" --url https://vault.example.com
```

Restore verifies checksums, the key format and permitted archive members; rejects symlinks, traversal and existing destinations; creates a new Compose project and data volume; restores the exact key/data pair; then starts the backup's image version. It never overwrites a working vault. The public URL can change without rebuilding the frontend. Point DNS to the destination when moving hosts. Stop the old installation first if reusing its host ports.

Caddy's certificates are intentionally not included in vault backups. Public certificates are reissued; a restored localhost installation has a new local CA that must be trusted again. Keep the original installation and backup until you verify sign-in and secret decryption on the restored instance.

## Upgrade

Choose an actually published version tag or digest from the repository's package page:

```sh
python3 "$HOME/secretpod/scripts/host.py" upgrade --dir "$HOME/secretpod" --image ghcr.io/mnkhtrbukhbold/secretpod:VERSION
```

`VERSION` is a placeholder for the desired release; do not type it literally. The tool pulls before stopping the old app, takes a private backup, keeps the app stopped, changes the image, and waits for health. The key and data volume remain unchanged. It refuses unversioned images and `latest`.

An interrupted or failed upgrade leaves `upgrade-pending.json`, including the recovery backup location, and ordinary startup is blocked. Restore that backup into a new installation. Do not manually start the old image against a database the candidate may have migrated. This release has no earlier published baseline; the lifecycle test verifies replacement with a distinct image, while the backend suite exercises schema migration separately.

For management-tool or Compose changes, read the release notes and use the new source's tool as directed; changing the app image alone does not replace installed management scripts/templates.

## Existing development installations

The former source launcher and old Docker volume remain separate from new managed installations. Setup creates a fresh vault; it does not import your local `.env` or database. Preserve the old data and matching key. For migration, stop the old server, create a complete consistent backup, and use a separately reviewed conversion to the managed backup format before restoring. Never point two processes at the same vault or delete the old volume to resolve a lock.

## Verification and boundaries

`python3 tests/docker_lifecycle.py --image secretpod:test` exercises synthetic installation, certificate-verified local HTTPS, redirects, runtime URL loading, account/secret operations, repeated setup, restart, backup, image replacement, restore to a second URL, and failed-pull/overwrite refusal. It removes only its randomly named test projects/volumes. Unit tests cover configuration rejection, missing-key refusal, lock conflicts and unsafe backup input. Tagged release publication runs the lifecycle test before pushing the image.

Public ACME issuance requires your domain and DNS; local TLS tests do not establish that your domain is reachable. Native mobile/desktop distribution and multi-replica operation are outside this deployment path.

References: [Caddy automatic HTTPS](https://caddyserver.com/docs/automatic-https), [Docker Compose production guidance](https://docs.docker.com/compose/how-tos/production/).
