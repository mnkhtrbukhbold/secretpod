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

## Projects

The Projects card on the Secrets home page opens a project picker. Selecting a
project adds it to the current search and environment filters. The project
control above the secrets list reopens the picker; its clear button removes only
the project filter. All projects restores the combined list.

Owners and editors granted project creation permission can create projects in
the picker. Names are trimmed, limited to 80 characters, and unique within the
organization without regard to case. Empty projects persist across refreshes and
restarts. Existing project labels on secrets remain available without rewriting
those secrets. New secrets start in the selected project.

## Repeated requests and cooldowns

Sign-in/account creation and secret reveal controls wait two seconds after a
request finishes before accepting another request. The controls show the time
remaining; pressing Enter or clicking again before a screen rebuild cannot
submit a duplicate. Hiding a revealed value remains immediate, and values still
hide automatically after 30 seconds. Email and password length limits are also
checked locally before submitting; passwords are never trimmed.

The server shares one secret-access budget across reveal, credential reveal and
copy requests: **10 requests per rolling 10 seconds and 60 per rolling minute
per account**, across organizations, secrets, tabs and sessions. It reserves
quota before queuing the secret transaction. Rejected requests return a retry
time without decrypting a value or adding an activity event. Accepted requests
retain their activity records. Copy confirmation remains independently retryable
and idempotent after the access budget is exhausted.

Authentication retains its **10 attempts per normalized email per 15 minutes**,
**60 attempts per minute across the server**, and **four simultaneous password
hashes**. Registration shares these budgets; profile password checks have their
own account key and share the global budget. Successful sign-in no longer clears
the email budget. Rejected attempts do not extend the waiting period or allocate
new email buckets.

These limits live in memory in the single server process and reset on restart.
Secret-access tracking holds at most 4,096 active account budgets and refuses
new budgets until an existing one expires when that capacity is reached.

## Saved list preferences

The browser remembers the page size and current page independently for Secrets,
Members, Activity, received invitations and sent invitations. Page sizes are
10 (default), 25, 50 and 100. Secrets search, project and environment filters and
Activity date, project, action and user filters also restore after a reload.
Changing filters or page size returns that list to its first page.

Preferences are separate for each API server and account; organization lists
also keep their own pages and filters per organization. The selected organization
restores only if the account still has access. Deleted rows can move a saved page
back to the last available page. Browser storage failures leave the lists usable
and display a warning. Native targets currently use in-memory preferences.

`PageSizeStore` retains existing size keys. `ListStateStore` stores versioned
`ListViewState` objects with a page and filter map for reuse by future lists.
These stores contain display settings, including search text, never list rows or
decrypted secret values. Sign-out retains preferences for the same account.

## Member roles and project access

Owners can use **Members → Edit access** to change another member between Reader
and Editor and select their readable and writable projects. The same controls
are available when creating an invitation. Each access section shows every
project with an individual checkbox. **Selected projects only** grants exactly
the checked projects. **All projects, with exclusions** includes future projects
and denies unchecked projects. Read and write choices are independent, but
writing requires read access to the same project. Read-all access can be combined
with writes limited to selected projects.

**Can create projects** is a separate Editor permission. Enabling it converts
both access sections to exclusions, preserves restrictions on existing projects,
and grants read/write access to future projects, including projects the member
creates. Unchecking it disables creation while retaining the displayed project
permissions. Owner membership is protected from role changes.

The server checks scopes on every secret operation and filters lists, counts,
project choices and activity before pagination. Moving a secret requires write
access to both its current and destination projects. Historical events without
project evidence are visible only with all-project read access. Existing grants
remain editable when a legacy project loses its last secret.

SQLite schema 11 extends the schema 9 allow lists with `deniedReadProjects`,
`deniedWriteProjects`, and `canCreateProjects` on memberships and invitations.
Null allow lists include all projects except explicit denials; empty allow lists
grant none. Missing creation flags preserve legacy behavior: only unrestricted
Editors can create projects. Explicit flags distinguish all-project writers who
cannot create projects. Creation checks also apply when saving a secret under a
new project name. Deploy the regenerated API and rebuilt frontend together using
the normal launcher.

## Disabling member access

Owners can choose **Disable access** on a member row to suspend organization
access while retaining the membership, role, and project permissions. Disabled
members stay visible to the owner with an **Access disabled** label and an
**Enable access** action. Owners cannot disable themselves or another owner.
Removing the membership remains a separate action.

Disabling uses the same secret review as removal: existing, unexpired secrets
linked to the member's recorded create, edit, reveal, and copy activity, sorted
by type and name with project and environment shown. Deleted secrets are excluded. The owner
selects which secrets to mark **Needs rotating**; the flags and suspension commit
together. A changed review must be refreshed before confirming. Enabling access
restores the saved permissions and leaves rotation flags unchanged.

The server excludes disabled memberships from organization lists and rejects
organization operations even with an existing login session. Other organizations
and the member's personal account remain accessible. Refresh clears a revoked
organization and its open secret dialogs, including when access is revoked
between requests. Existing clients learn the change on their next refresh;
there is no push notification or remote erasure of previously copied values.

SQLite schema 10 adds a nullable membership access flag. Existing memberships
remain enabled and the migration does not rewrite secret ciphertext. Deploy the
regenerated backend and frontend together using the normal launcher.

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
