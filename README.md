# SecretPod

A self-hostable secrets manager for developers and small teams, built with Flutter and Serverpod.

- Store encrypted credentials by project and environment.
- Manage team invitations, roles, and project access.
- Revoke access and flag secrets for rotation.

## Self-host

Requires Docker Compose v2, curl, and a domain pointing to your server.

```sh
curl -fsSL https://raw.githubusercontent.com/mnkhtrbukhbold/secretpod/v0.1.1/scripts/install.sh | sh -s -- --url https://vault.example.com
```

Replace the hostname with your domain. Installation awaits the pending prebuilt image release.

See the [self-hosting guide](docs/self-hosting.md) for HTTPS setup, backups, and upgrades.

## Develop locally

Install Flutter 3.47.7 and Git, plus OpenSSL on macOS/Linux. From the repository root, run:

**Windows**

```powershell
.\scripts\start.ps1
```

**macOS / Linux**

```sh
sh scripts/start.sh
```

Open **http://localhost:8082** and create an account. The launcher handles setup and startup; SQLite is included.

See the [development guide](docs/development.md) for main features and modules.

## Interactive demo

[Try the live SecretPod demo](https://secretpod-production.up.railway.app).

The repository includes a fictional demo database and a separate Flutter entrypoint.
Demo edits stay in your browser until **Reset demo** or clearing site data. The
normal application continues to use its encrypted server-side vault.

See [the demo guide](docs/demo.md) for local use and Railway deployment from the
`codex/demo` branch. All sample credentials are deliberately nonfunctional.
