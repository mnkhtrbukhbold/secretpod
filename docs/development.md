# Develop SecretPod from a source download

Install Flutter **3.47.7**, which includes Dart **3.13.5**, and add its `bin`
directory to `PATH`. These are the tested versions. The package constraints
currently require Dart 3.12.2 or later and Flutter 3.44.4 or later within their
compatible major versions; a newer release still needs validation. Install Git
as required by Flutter. On macOS/Linux, install OpenSSL to generate the initial
master key. Windows uses its built-in cryptographic random generator.

Check the installation in a new terminal:

```text
flutter --version
dart --version
flutter doctor
```

For this web workflow, missing Android, iOS, or desktop toolchains are not
blockers. Flutter web support and network access to download Dart packages and
Flutter web build artifacts are needed. There is no database service to install:
the backend uses embedded SQLite. Docker, a cloud account, email delivery, and a
Serverpod CLI installation are not required to run the checked-in source.

## First launch

Extract or clone the source, open a terminal in the repository root, and run:

```powershell
# Windows PowerShell
.\scripts\start.ps1
```

```sh
# macOS / Linux
sh scripts/start.sh
```

If Windows blocks locally downloaded scripts, inspect the source and use a
process-scoped execution policy for this invocation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start.ps1
```

The launcher creates the ignored `.env` once, installs the workspace's Dart
dependencies, builds Flutter web, replaces the generated server web app, and
starts Serverpod in development mode. Open **http://localhost:8082**. The API
uses **http://localhost:8080**; Insights is configured on **8081**. Press Ctrl+C
in the launcher terminal to stop the server. Development listeners can bind
network interfaces, so use the deployment instructions for public hosting.

No generated web bundle, package cache, local password file, or vault data is
needed in the source download. An empty installation has no accounts or secrets.
Register your first account through the web app. The application configuration
comes from the server's `/app-config.json`; the development configuration points
to the separate API listener. `/healthz` on the web listener provides a read-only
health check.

## Subsequent launches and data

Re-run the normal command after changing frontend code or downloading an updated
version. The successful build replaces the complete generated `web/app` folder,
so removed assets do not survive from an older version. A failed Flutter build
does not remove the previous served app.

When the existing web build is still current, skip only the web build:

```powershell
.\scripts\start.ps1 -SkipBuild
```

```sh
sh scripts/start.sh --skip-build
```

Both commands still install dependencies. They reject a missing or incomplete
web bundle with instructions to run a full build. They do not detect whether a
complete bundle is out of date; rebuild after source changes.

The master key stays in root `.env`, and the vault normally stays in
`secretpod/secretpod_server/data`. Never discard the matching key when retaining
or restoring the vault. If the key is missing and a database or legacy vault is
already present, the launcher refuses to generate a replacement key.

`SECRETPOD_MASTER_KEY` can supply a base64-encoded 32-byte key directly.
`SECRETPOD_DATA_DIR` selects another storage directory; a relative path is
resolved from the terminal's starting directory. The old `PODVAULT_MASTER_KEY`
and `PODVAULT_DATA_DIR` names are still supported, with the new names taking
precedence. Existing environment values take precedence over `.env`. Shell
environment changes made by PowerShell persist in that terminal; open a new
terminal or clear those variables before switching vaults.

Dependencies use the ignored `.cache/pub` unless `PUB_CACHE` is already set.
The first install requires network access; later launches can reuse that cache.
Do not include caches, `.env`, passwords files, data directories, or logs in a
public source archive.

## Isolated local instances

Use a separate source checkout and separate data/key pair to test a fresh
installation while another instance runs. Set all three listener ports and
their public ports consistently before launching:

```powershell
$env:SERVERPOD_API_SERVER_PORT = '18080'
$env:SERVERPOD_API_SERVER_PUBLIC_PORT = '18080'
$env:SERVERPOD_INSIGHTS_SERVER_PORT = '18081'
$env:SERVERPOD_INSIGHTS_SERVER_PUBLIC_PORT = '18081'
$env:SERVERPOD_WEB_SERVER_PORT = '18082'
$env:SERVERPOD_WEB_SERVER_PUBLIC_PORT = '18082'
# In a separate source checkout with no inherited key/data environment values:
.\scripts\start.ps1
```

```sh
SERVERPOD_API_SERVER_PORT=18080 SERVERPOD_API_SERVER_PUBLIC_PORT=18080 \
SERVERPOD_INSIGHTS_SERVER_PORT=18081 SERVERPOD_INSIGHTS_SERVER_PUBLIC_PORT=18081 \
SERVERPOD_WEB_SERVER_PORT=18082 SERVERPOD_WEB_SERVER_PUBLIC_PORT=18082 \
sh scripts/start.sh
```

Open `http://localhost:18082` for this instance. Never point two processes at the
same vault directory. If a requested port is already occupied, stop the instance
you own or choose unused ports; the launcher does not terminate other processes.

## Checks and troubleshooting

Launcher behavior tests use temporary synthetic files and fake external tools;
they never start the application or read an existing vault:

```powershell
.\scripts\test-start.ps1
```

```sh
sh scripts/test-start.sh
```

For application checks, set `PUB_CACHE` to the repository's `.cache/pub` if you
want to reuse launcher downloads, then run from `secretpod`:

```sh
flutter pub get
dart analyze
cd secretpod_server
dart test
cd ../secretpod_flutter
flutter test
flutter build web --no-web-resources-cdn
```

On Windows, an active server can lock the SQLite native library used by a test
build. Run tests in a separate source checkout or stop your own development
server first. A dependency failure usually needs the supported Flutter SDK,
network/proxy configuration, or writable SDK/Pub cache directories. A vault-key
error needs the vault's original key; generating another key will not repair it.

Protocol changes require Serverpod **4.0.3** generation; the checked-in generated
client and server code already suffice for a normal source download. See the
root README for generation commands and `release.md` for recorded release checks.
