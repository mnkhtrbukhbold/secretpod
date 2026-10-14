# SecretPod

A self-hostable organization secrets manager built with **Flutter + Serverpod**. The first version is a working shared vault: accounts, organization roles, encrypted secret storage, and an activity trail.

The Dart workspace is `secretpod/`, containing `secretpod_server`, `secretpod_client` (generated), and `secretpod_flutter`. Folder names, package imports, native application identifiers, and deployment configuration use this name.

## Self-host with Docker Compose

Docker Compose is the primary deployment path: a prebuilt SecretPod image, Caddy HTTPS, runtime URL configuration, and persistent keys and SQLite data. Install Docker with Compose v2, Python 3.10+, curl and tar; point your domain at the server and allow ports 80/443. Then:

```sh
curl -fsSL https://raw.githubusercontent.com/mnkhtrbukhbold/secretpod/v0.1.0/scripts/install.sh | sh -s -- --url https://vault.example.com
```

Replace the hostname. Setup generates the key once and installs private management tools/configuration in `~/secretpod`; it never builds Flutter on the host. Read the [self-hosting guide](docs/self-hosting.md) for local HTTPS, Windows setup, backups, restores and upgrades. The image targets Linux amd64 and runs one app instance per vault.

## Develop locally

Requires Flutter 3.47.7 / Dart 3.13.5 (the tested toolchain) or a compatible newer stable release. SQLite is embedded through Serverpod; no separate database service, Docker, external account, or email service is needed.

From this directory on Windows:

```powershell
.\scripts\start.ps1
```

On macOS/Linux (Flutter and OpenSSL installed):

```sh
sh scripts/start.sh
```

Open **http://localhost:8082**. Create an account, create an organization, then add a secret. Registration uses a password of at least 12 characters. There are no default credentials, users, or seeded secrets.

The launcher installs dependencies, builds Flutter web with local rendering resources, generates a random 256-bit master key once in the ignored root `.env`, and starts Serverpod. Subsequent launches can skip rebuilding:

```powershell
.\scripts\start.ps1 -SkipBuild
```

```sh
sh scripts/start.sh --skip-build
```

The API listens on port **8080**, the web application on **8082**, and Serverpod Insights uses **8081** if configured. Local development uses HTTP; Serverpod binds network interfaces, not just loopback. Do not expose these development listeners directly to the Internet. The production Compose deployment exposes only its HTTPS proxy; localhost installations bind to loopback.

## What works

- Browser Back and Forward navigate Secrets, Activity, Members, My invitations, and Profile settings. Their hash URLs also support direct links and refresh. Open dialogs get temporary history entries; Back respects unsaved-secret confirmation, and discarded dialogs are not reconstructed by Forward.
- Register, sign in, and sign out; sessions expire after 12 hours. Browser sign-in survives refresh, new tabs, and closing/reopening the browser on the same site and browser profile. Startup validates the saved session before opening the workspace. Sign-in changes and logout synchronize across open tabs, including closing any open secret dialogs. Temporary connection failures offer a retry.
- Create and switch organizations. Owners can use the organization menu → **Rename organization** to change its name (1–80 characters). The change is recorded in Activity and preserves the organization ID, memberships and secrets.
- Invite an email address as **reader** or **editor**, whether or not an account exists. The creator is the **owner**. Invitations remain pending until the recipient accepts; creating an invitation grants no access. Editors manage secrets; readers can list and reveal them.
- Owners can remove readers and editors from **Members**. The confirmation lists each existing, unexpired secret the member created, modified, revealed, or requested to copy, including its type, project, environment, and expiry. Choose which secrets to mark **Needs rotating**; all are selected initially. Removing the member and setting the selected flags commit together. The owner cannot be removed. The account and its other organization memberships remain intact.
- **Needs rotating** appears in the secret list and details. Owners and editors can mark or clear the flag from secret details. Saving a genuinely different secret value clears it; metadata edits, unchanged values, and username-only edits preserve it. Marking does not replace or revoke the actual credential. Clearing a checkbox during removal never clears an existing flag.
- Owners create invitations from **Members**, supply a name/email/role, and copy a private link to share. Sent invitations appear immediately in the Members invitation list. Existing users open their personal inbox through the **top-right profile circle → My invitations**; its badge counts pending invitations addressed to them. New users can create an account from the link, edit their suggested name, choose a password, and accept in one transaction. Invited email addresses stay fixed. Recipients can decline without joining, including without creating an account.
- Track pending, accepted, declined, revoked, blocked and expired invitations. Owners can revoke pending links. Links expire after seven days. Invitation creation is limited to 20 per owner per hour and 100 pending per organization; declined recipients cannot be reinvited by that organization for seven days.
- Open **Account → Profile settings** to edit your display name, change email or password, choose a theme, manage receiving invitations, or sign out. Email and password changes require your current password. Changing email keeps your organization memberships and updates the address used for sign-in and invitations. Old-address invitations do not transfer. Changing password signs out other sessions while retaining the current session. Profile pictures are not included.
- Under **Profile settings → Appearance**, choose **System**, **Light**, or **Dark**. System is the default and follows device appearance changes. Your selection is saved to your account. Both palettes preserve the existing layout and components.
- Under **Profile settings → Who can invite you?**, choose **Allow all**, **Same email domain only**, or **Block all**. The inbox links to these settings. Both account pages work without organization membership; **Back to workspace** restores the previous workspace page. Members, Activity, and received/sent invitations share the Secrets table style, with labeled desktop columns and stacked mobile rows. Domain filtering compares exact email domains; it does not verify company ownership. Changing preferences also blocks incompatible pending invitations. Existing team memberships are unaffected.
- Store API keys, environment variables, passwords, **username and password** pairs, certificates, and other text secrets. Text values support multiple lines and up to 65,536 characters; credential passwords use a masked single-line field.
- Add an optional HTTP/HTTPS URL and expiry date to any secret. Empty expiry means **Never expires**. Expiry is a calendar date: an item is marked expired after that day in the viewer's local calendar. This is informational; it does not revoke credentials or prevent reveal/copy.
- Group secrets by project and Development / Staging / Production; search metadata and filter by environment.
- Open **Projects** from the Secrets summary to browse all project names and secret counts in the shared light/dark design. Select a project to filter its secrets. The list adapts to narrow screens and renders rows as you scroll.
- Reveal and copy values; reveal automatically hides after 30 seconds. Clipboard contents remain until replaced by the user or operating system.
- Edit details or rotate credentials and increment their version; leave credential fields blank while editing to preserve their current encrypted values. Clearing URL or expiry removes that metadata. Delete with confirmation. Previous credential values are not retained.
- Dialog headers and action buttons remain fixed while their contents scroll. Save/Cancel, invitation actions and Edit/Delete stay accessible; invalid fields and operation errors scroll into view. Adding or editing a secret asks **Keep editing** or **Discard changes** before closing a changed form through Close, Cancel, Escape or Back. Untouched forms close immediately; saving blocks dismissal, and outside clicks do not dismiss the editor.
- Reveal username/password together or copy either field separately. Copy history identifies the field copied; changes to username, URL, and expiry appear in the item's Activity list without storing their values in audit details.
- Changing a username/password item to a single-value type removes its saved username; the editor shows a removal notice before saving. Entered usernames and passwords retain their exact whitespace.
- Page through Members, Activity, Secrets, and received/sent invitations with 10 rows by default, selectable 25/50/100-row pages, Previous/Next controls, and full result counts. Each list remembers its size in this browser separately for each account and API server, including after refresh and sign-out/sign-in. Secret search and project/environment filters apply across all records. Organization activity includes events beyond the former 200-event limit. Secret creation, rotation, deletion and reveals, plus invitation issuance and authenticated responses, are recorded without secret values. Invitations also retain their status and timestamps, including declines without an account.
- Open a secret to see its own Activity list: who created, revealed, copied or modified it, the version involved, changed field names, and local timestamps. Load older entries in pages of 10; refresh the list to see teammates' actions.
- Use a responsive Material 3 interface with desktop side navigation and mobile bottom navigation. Dropdowns and profile/organization menus use shadcn-inspired compact outlined triggers, white panels with thin borders, neutral hover rows and selected-value checkmarks. Menu labels wrap at larger text sizes, with larger touch targets on narrow screens.

## Modules

| Module | Responsibility | Location |
| --- | --- | --- |
| Storage | SQLite tables, transactions, schema versioning, JSON import, process lock | `secretpod/secretpod_server/lib/src/storage/` |
| Crypto | AES-256-GCM, random tokens, password derivation | `secretpod/secretpod_server/lib/src/crypto/` |
| Account | Registration, password verification, expiring sessions, throttling | `secretpod/secretpod_server/lib/src/account/` |
| Organization | Membership and owner/editor/reader authorization | `secretpod/secretpod_server/lib/src/organization/` |
| Invitation | Pending invitation lifecycle, recipient consent, signup, preference and rate checks | `secretpod/secretpod_server/lib/src/invitation/` |
| Tracking | Item and actor identities, per-secret history, copy acknowledgments, value-free activity committed with each mutation | `secretpod/secretpod_server/lib/src/tracking/` |
| Vault | Secret validation, listing, reveal, rotation and deletion | `secretpod/secretpod_server/lib/src/vault/` |

The backend uses **Serverpod 4.0.3** with generated typed endpoints and a generated Dart client. Persistence is isolated behind `VaultStore`. `SqliteVaultStore` uses Serverpod's `DatabaseProvider` SQLite adapter and `Database.transaction` with parameterized SQL. Its connection pool, schema versioning and queries live entirely in the storage module; this module does not use the server-wide `session.db` pool or generated ORM migrations. SQLite support is part of [Serverpod 4](https://docs.serverpod.dev/upgrading/upgrade-to-four).

The database is `secretpod/secretpod_server/data/vault.sqlite` (or inside `SECRETPOD_DATA_DIR`). Separate relational tables hold accounts, sessions, organizations, memberships, encrypted secrets, activity, and invitations; an eighth table stores small vault metadata values. Records are not stored as a single JSON document. The existing snapshot callback interface is retained for service compatibility: each operation still reads the vault into memory, while writes apply changed/deleted rows in one database transaction.

Invitation delivery currently uses **manually shared links**, not email. Copy the link before closing the creation dialog; if it is lost, revoke and issue another invitation. Store only token digests on the server. Existing-account acceptance requires both the private link and sign-in as the invited email; the inbox alone cannot grant access. Link tokens are kept in URL fragments rather than web-server query strings. No email verification or SMTP service is configured. Old clients attempting immediate `addMember` receive an explicit error.

## Storage and trust model

- Secret values, including saved service passwords, are encrypted using AES-256-GCM. Usernames use a separate encrypted field with a distinct authenticated context. Each encryption uses a fresh nonce and binds the ciphertext to its organization, secret, and field. Metadata (names, descriptions, projects, URLs, expiry dates), account emails, memberships, and activity are plaintext.
- SecretPod account login passwords use PBKDF2-HMAC-SHA256 with 600,000 iterations and random salts. The server stores random session tokens only as SHA-256 digests. The browser keeps its opaque bearer token in persistent `localStorage`, namespaced by API URL; account details, passwords and secret values are not persisted there. This storage is accessible to same-origin JavaScript, not an HttpOnly cookie. Server expiry and revocation remain authoritative; reopening the browser does not extend the 12-hour session. Browser privacy settings or cleared site data can remove the saved sign-in. Native clients currently retain sessions in memory only.
- Authentication endpoints have per-email and global in-memory limits, plus a four-operation password-hashing concurrency cap. Throttles reset on process restart.
- Membership and role checks run on every secret operation. Listing does not return ciphertext or plaintext values. Endpoint session logging is disabled.
- SQLite commits each change and its audit events in one transaction, with foreign keys, primary keys, indexes, and rollback on failure. SQL values are bound parameters and query logging is disabled. A lock prevents a second server process from opening the same directory. This implementation remains intended for **one server instance on local persistent disk**, not shared network storage or multiple replicas.
- The server operator holds the master key and can decrypt values. This is **encryption at rest**, not end-to-end encryption or a zero-knowledge system.

**Keep the master key with a protected backup: losing `.env`/`SECRETPOD_MASTER_KEY` makes the stored values unrecoverable.** A server refuses to open an existing vault with the wrong key.

For a consistent backup, stop the server and copy the **entire data directory** and root `.env` to protected backup storage. Include any `vault.sqlite-wal` / `vault.sqlite-shm` sidecar files that remain after shutdown; do not copy only the main database while it is running. Restore the saved data directory as a complete set into an empty destination, together with its matching master key. Do not mix a restored database with stale sidecars. Do not commit these files. `SECRETPOD_DATA_DIR` selects a different local data directory; `SECRETPOD_MASTER_KEY` can be injected instead of read from `.env`.

On first startup with an existing `vault.json`, SecretPod validates the format, master-key check, and every encrypted secret, then imports all records into SQLite in a single transaction. IDs, ciphertext, password hashes/salts, session digests, timestamps, versions and list ordering are preserved. Failed imports roll back and can be retried after correcting the source; the original JSON is never modified or deleted. A successfully initialized SQLite database is authoritative and the JSON is never re-imported. The retained JSON is a **pre-migration recovery snapshot**, not a current backup. Do not remove the SQLite database or run the old JSON-based application against that snapshot unless deliberately restoring the old state.

The earlier `PODVAULT_MASTER_KEY` and `PODVAULT_DATA_DIR` environment names remain accepted for compatibility; the new names take precedence. Launchers can also read the old master-key label in `.env`. An existing vault's encrypted startup marker is upgraded automatically with the same key, without re-encrypting secret records. Deploy the regenerated client and server together because the generated protocol namespace is now `secretpod`.

This MVP does not implement MFA, SSO, account recovery, email verification, member role changes, service-account credentials, automatic credential rotation, secret value history, environment import/export, invitation email, audit-log tamper evidence, or external KMS. Registration is open on the instance. It has not had a production security audit. The SQLite adapter retains the in-memory snapshot interface and is deliberately a small-installation adapter. Secret values remain application-encrypted; the SQLite file as a whole is not encrypted.

## Tracking each secret

Member removal reviews use permanent actor and secret IDs from the complete recorded history, not display names or just the current secret version. Deleted secrets and secrets past their expiry date in the owner's local calendar are excluded; a secret expiring today is included. Older events without identifiers cannot establish access and are not guessed into the review. The server rechecks the eligible secret IDs at confirmation: if the set changed while the dialog was open, refresh the review and choose again. Removal and rotation changes are audited without secret values.

SQLite schema 6 adds a nullable rotation flag; existing records default to unmarked without rewriting ciphertext. Deploy the regenerated server and client together. Restart the backend and rebuild/reload the web app with the root launcher to activate this feature. Marking a secret for rotation does not itself rotate the credential at its provider.

New secret events use a permanent secret ID and authenticated account ID, alongside the actor's name/email snapshot. Renaming a secret keeps its history, and same-name secrets in different projects remain separate. Readers can view history and copy values; editing still requires an editor or owner. Modification entries record changed field names and the version, never old/new secret values. Saving an identical value does not claim the value changed. Deleted-secret events remain in organization Activity.

The **Copy** button retrieves the current value and commits a `copy requested` event before returning it. After the clipboard operation succeeds, the app acknowledges the event and the server marks it `copied`. A failed clipboard write remains a request. If confirmation fails after copying, the dialog reports that explicitly and offers **Retry confirmation**, without copying again. Closing the dialog discards that retry state, while the request remains durable. The event timestamp is the server's request time; confirmation is an acknowledgment from the authenticated app, not independent proof of the operating system's clipboard contents. Manual copying of revealed text or use outside this app cannot be detected; the reveal itself remains recorded.

SQLite schema version 2 adds nullable tracking fields in a transaction. Existing rows, ciphertext and keys are preserved. Older events have only target names, so they remain in organization Activity and are not guessed into a secret's history. New events are linked from the upgrade onward. This is activity history; previous secret values are still not retained.

## Deployment operations

Use the [self-hosting guide](docs/self-hosting.md) for setup, runtime configuration, HTTPS, backup, restore and upgrade. Use the [developer guide](docs/development.md) for a fresh source download and local launch, and the [release guide](docs/release.md) for image builds, CI and safe source publication.

## Development and verification

### Reusing pagination

Every list-returning endpoint supports optional `offset` (zero based, default 0)
and `limit` (default 10, allowed 1–100): `vault.organizations`, `vault.members`,
`vault.listSecrets`, `vault.activity`, `vault.secretActivity`,
`vault.memberRemovalSecrets`, `invitation.inbox`, and `invitation.outgoing`.
A page shorter than `limit` marks the end; an exact
multiple may require one final empty request. Invalid bounds return a
`VaultException`. `secretActivity` also retains its event cursor for stable
older-history loading; a cursor and a nonzero offset cannot be combined.

New list services should reuse `Pagination` in
`secretpod/secretpod_server/lib/src/paging.dart`. Perform access checks, filter
the full collection, establish a deterministic order, then call
`Pagination(offset: offset, limit: limit).apply(items)`. This class owns the
default size, maximum size, validation and slicing. Endpoint wrappers accept
nullable parameters and use `Pagination.defaultLimit` when no limit is supplied.
Add matching endpoint tests and regenerate the Serverpod client after changes.

`vault.listSecrets` additionally accepts `query`, `project`, and `environment`.
`vault.summary` returns organization-wide counts, the matching secret count, and
project counts so paging does not change dashboards or project choices. Flutter
uses the shared `PaginationControls` widget and `PaginationSettings` for the
10-row default and the 10/25/50/100 choices. Its parent keys it by the request
revision so a failed page-size change restores the authoritative selection.
Organization menus and invitation lists follow API pages, deduplicate by ID, and
retain complete choices and badge counts; the three main lists fetch only their
selected page. Invitations page the complete fetched collection so badge totals remain accurate. The shared `ListTable` components provide the Secrets table styling across workspace and invitation lists. `PageSizeStore` saves only validated display sizes in browser localStorage; native targets use memory storage. Page indices reset on reload while selected sizes restore before requests. Failed or stale page requests do not overwrite saved sizes. Secret details load older activity in 10-event cursor batches.

Offset pages reflect the current data on each request, rather than a frozen
snapshot across requests. The existing SQLite adapter still reads full vault
snapshots internally; paging bounds responses and displayed rows, not database
read volume. No schema or encrypted data migration is required. Restart the
backend and reload the updated client together to activate the new contract.

### Publishing the source

Publish from this directory so the root `.gitignore` applies. Keep the local
`.env`, Serverpod passwords, vault data, backups, logs, and tool caches private.
The ignore rules cover environment-file variants, database files and sidecars,
private keys, and common credential files. Docker uses a separate allowlist of
build inputs; it intentionally includes the generated Flutter web app.

Before the first push, inspect `git status --short` and `git diff --cached`,
then scan the staged files and any existing history with a secret scanner such
as [Gitleaks](https://github.com/gitleaks/gitleaks). Never force-add ignored
files or upload a ZIP of this working directory: it contains private runtime
files even when Git ignores them. Create source archives with `git archive`
from a reviewed commit. Ignore rules do not remove files already tracked or
erase earlier commits; previously published credentials require revocation
and history cleanup. Keep the vault and its matching master key in protected
backup storage, not in the public repository.

Screenshots must use synthetic data and must not show real accounts, secret
values, invitation links, or browser session tokens. Test credentials are
fixtures for isolated tests and must never be reused in a deployed instance.

The root `.cache/pub` is a project-local package cache used by the launch scripts. You may use your normal Pub cache instead. If using this cache in another terminal:

```powershell
$env:PUB_CACHE = "$PWD/.cache/pub"
cd secretpod
flutter pub get
dart analyze
cd secretpod_server
dart test
cd ../secretpod_flutter
flutter test
flutter build web --no-web-resources-cdn
```

To regenerate models and client after endpoint or `.spy.yaml` changes:

```sh
dart pub global activate serverpod_cli 4.0.3
cd secretpod/secretpod_server
dart pub global run serverpod_cli:serverpod_cli generate --no-analytics
```

Do not edit generated client/protocol files manually. The native Flutter platform scaffolds are included, but only web was built and checked. Physical devices need `--dart-define=SERVER_URL=http://YOUR_SERVER_IP:8080/` for local development.

The automated checks cover encryption and tampering, storage restart and rollback, cross-organization rejection, reader permissions, duplicate secret identity, version updates, audit redaction, session revocation, concurrent login limits, actual Serverpod HTTP transport, UI validation/search/filtering, mobile layouts, expired/offline sign-out, and multiline paste preservation. See the [release guide](docs/release.md) and repository Actions runs for deployment verification.

## Hackathon context

The organizer's event listing describes a Serverpod full-stack application hackathon and lists **14 October** as the submission deadline: [Build Something Real](https://luma.com/builde-mked). The linked [BuilderBase event](https://builderbase.com/event/build-something-real-the-serverpod-hackathon) is the user's original reference. No submission or publication has been made.

Design references: [Material 3](https://m3.material.io/) and [Material components in Flutter](https://docs.flutter.dev/ui/widgets/material). The implementation uses Flutter's Material 3 widgets and Google-inspired layouts; it does not claim complete implementation of every Material 3 Expressive component.
