# Self-host SecretPod

Docker Compose is the primary deployment path. One prebuilt SecretPod image contains the Flutter website and Serverpod API. Caddy supplies HTTPS. SQLite, the master key and certificates persist separately from application containers. No Flutter, Dart, PostgreSQL, Redis or cloud account is required on the host.

## Requirements

- A Linux server with Docker Engine and Compose v2, curl and a POSIX shell. The first release image targets Linux amd64. Docker Desktop can run it on Windows/macOS; ARM hosts need amd64 emulation.
- For public HTTPS, a hostname whose A/AAAA records point to this server, reachable TCP ports 80 and 443, and outbound access for pulling images and obtaining certificates. Remove incorrect AAAA records. Caddy obtains and renews publicly trusted certificates automatically when these conditions hold.
- Local persistent disk. Run one app instance per vault. Do not mount SQLite on network storage or scale the app service to multiple replicas.
- Windows uses PowerShell and Docker Desktop in Linux-container mode. Python is included in the temporary management container; it is not a host prerequisite. Use a local Docker context; remote SSH/TCP engines are not supported by these launchers.

## One-command public installation

After prerequisites and DNS are configured, replace the hostname:

```sh
curl -fsSL https://raw.githubusercontent.com/mnkhtrbukhbold/secretpod/v0.1.1/scripts/install.sh | sh -s -- --url https://vault.example.com
```

The bootstrap downloads a small shell launcher and runs the prebuilt `ghcr.io/mnkhtrbukhbold/secretpod-manager:0.1.1` management container. That tool pulls `ghcr.io/mnkhtrbukhbold/secretpod:0.1.1`, creates `~/secretpod`, generates the master key once, and starts Compose. Open your HTTPS URL and create an account. There are no default credentials. Registration is currently open to anyone who can reach the instance; use your network access controls for a private team installation.

If the official application image cannot be pulled anonymously, setup downloads the identical prebuilt image from the public GitHub Release, verifies its SHA-256 checksum and loads it into Docker. It does not fall back to compiling source. Release archives also provide an offline distribution format. The manager image must be anonymously pullable or already loaded; preload the manager, app and Caddy images for an offline installation.

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
sh "$HOME/secretpod/scripts/host.sh" trust-cert --dir "$HOME/secretpod"
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
| `scripts/host.sh`, `scripts/host.ps1` | Retained management launchers; source download and host Python are not required |
| `backups/` | Backups automatically created before upgrades |

The named `<project>_vault-data` volume holds the SQLite database. Caddy certificate state is in `<project>_caddy-data`; its internal configuration is in `<project>_caddy-config`. Container recreation preserves these volumes. Do not use `docker compose down -v` on an installation you intend to keep.

Keep the installation directory and backup directories private. The key file is readable inside the container but protected on the host by its parent directory. Losing the matching master key makes encrypted values unrecoverable. The operator can decrypt secrets; this is encryption at rest, not zero-knowledge encryption.

## Runtime routing

Only Caddy publishes ports. `/api/` is forwarded to the app's private API port 8080 with the prefix removed; the website goes to private port 8082. `/app-config.json` supplies the browser's API URL at runtime and is never cached. The image is identical for every hostname. Production requires an HTTPS public origin and rejects API requests carrying a different browser Origin. Health checks use `/healthz` after the vault has initialized.

`SECRETPOD_PUBLIC_URL` and `SECRETPOD_API_URL` are public configuration. `SECRETPOD_MASTER_KEY_FILE` points to the read-only key file. Direct key environment variables remain available for source development, but combining a key file and a key environment variable is rejected. None belongs in a Docker build argument.

## Daily operations

These examples use the default installation location. On Windows, replace `sh "$HOME/secretpod/scripts/host.sh"` with `& "$HOME/secretpod/scripts/host.ps1"`; the arguments are the same:

```sh
sh "$HOME/secretpod/scripts/host.sh" status --dir "$HOME/secretpod"
sh "$HOME/secretpod/scripts/host.sh" stop --dir "$HOME/secretpod"
sh "$HOME/secretpod/scripts/host.sh" up --dir "$HOME/secretpod"
```

Each command starts a temporary manager container and removes it on exit. It contains Python and Compose, mounts the local Docker socket and the selected installation/backup parent directories, and operates with Docker administrative access. On Linux it writes files as your user; on Windows the launcher protects the destination with a private ACL before writing keys. Keep the parent directories present and use ordinary local paths, without symlinks/junctions or commas.

Image pulls use the host Docker CLI, so an existing `docker login` also works for custom private images. Credentials and credential-helper files are not copied into the manager. `--no-pull` uses preloaded images, including the manager. Choose an installation under your home directory, `/opt`, or `/srv`; system runtime directories are rejected.

Operations on the same installation are serialized. After a crashed management process, a lock can remain; verify that no management process is still running before removing the lock named in the error. Never remove locks to run operations concurrently.

## Backup

```sh
sh "$HOME/secretpod/scripts/host.sh" backup --dir "$HOME/secretpod" --backup "$HOME/secretpod-backup-2026-10-14"
```

The destination must not already exist. Backup stops the app, archives the complete data volume, saves its matching key and manifest, writes SHA-256 checksums, verifies the archive, and resumes the app if it was running. This causes brief downtime. Never copy only a running SQLite main file.

The backup contains both ciphertext and its decryption key. It is a private directory, not an encrypted export: store it on protected or encrypted backup storage. Checksums detect corruption, not malicious modification. Treat restore input as a trusted backup.

## Restore and move to another host

Copy the complete backup directory to the destination machine. Use the management script from a source download or the retained installation. Restore into a directory that does not exist:

```sh
sh scripts/host.sh restore --dir "$HOME/secretpod-restored" --backup "$HOME/secretpod-backup-2026-10-14" --url https://vault.example.com
```

Restore verifies checksums, the key format and permitted archive members; rejects symlinks, traversal and existing destinations; creates a new Compose project and data volume; restores the exact key/data pair; then starts the backup's image version. It never overwrites a working vault. The public URL can change without rebuilding the frontend. Point DNS to the destination when moving hosts. Stop the old installation first if reusing its host ports.

Caddy's certificates are intentionally not included in vault backups. Public certificates are reissued; a restored localhost installation has a new local CA that must be trusted again. Keep the original installation and backup until you verify sign-in and secret decryption on the restored instance.

## Upgrade

Choose an actually published version tag or digest from the repository's package page:

```sh
sh "$HOME/secretpod/scripts/host.sh" upgrade --dir "$HOME/secretpod" --image ghcr.io/mnkhtrbukhbold/secretpod:VERSION
```

`VERSION` is a placeholder for the desired release; do not type it literally. The tool pulls before stopping the old app, takes a private backup, keeps the app stopped, changes the image, and waits for health. The key and data volume remain unchanged. It refuses unversioned images and `latest`.

An interrupted or failed upgrade leaves `upgrade-pending.json`, including the recovery backup location, and ordinary startup is blocked. Restore that backup into a new installation. Do not manually start the old image against a database the candidate may have migrated. Automated lifecycle tests verify replacement with a distinct image, while the backend suite exercises schema migration separately.

Management launchers pin the manager image separately from the app image. For a new manager release, use that release's launchers; `SECRETPOD_MANAGER_IMAGE` can select a tested version or digest explicitly. Existing installations keep their Compose configuration and key. Changing the app image alone does not replace installed scripts/templates.

## Existing development installations

The former source launcher and old Docker volume remain separate from new managed installations. Setup creates a fresh vault; it does not import your local `.env` or database. Preserve the old data and matching key. For migration, stop the old server, create a complete consistent backup, and use a separately reviewed conversion to the managed backup format before restoring. Never point two processes at the same vault or delete the old volume to resolve a lock.

## Verification and boundaries

`python3 tests/docker_lifecycle.py --image secretpod:test` exercises synthetic installation, certificate-verified local HTTPS, redirects, runtime URL loading, account/secret operations, repeated setup, restart, backup, image replacement, restore to a second URL, and failed-pull/overwrite refusal. It removes only its randomly named test projects/volumes. Unit tests cover configuration rejection, missing-key refusal, lock conflicts and unsafe backup input. `python3 tests/container_manager_lifecycle.py` additionally runs the public launchers with Python removed from their PATH, including retained commands, spaces in paths, permissions, backup, upgrade, restore and failed-upgrade recovery. Python is required for contributors running this test harness, not for operators. Tagged release publication runs both lifecycle tests before pushing either image.

Public ACME issuance requires your domain and DNS; local TLS tests do not establish that your domain is reachable. Native mobile/desktop distribution and multi-replica operation are outside this deployment path.

References: [Caddy automatic HTTPS](https://caddyserver.com/docs/automatic-https), [Docker Compose production guidance](https://docs.docker.com/compose/how-tos/production/).
