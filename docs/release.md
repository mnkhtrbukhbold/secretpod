# Release and public-source workflow

Repository: https://github.com/mnkhtrbukhbold/secretpod

Images: `ghcr.io/mnkhtrbukhbold/secretpod:<version>` and `ghcr.io/mnkhtrbukhbold/secretpod-manager:<version>` (Linux amd64).

## Build and test

```sh
docker build -t secretpod:test .
docker build -f deploy/manager.Dockerfile -t secretpod-manager:test .
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tests/docker_lifecycle.py --image secretpod:test
python3 tests/container_manager_lifecycle.py --image secretpod:test --manager-image secretpod-manager:test
```

The Docker build installs the pinned Flutter toolchain, resolves the committed lockfile, builds web assets, and compiles the backend/native assets. The final image runs as UID/GID 10001. Its context uses an allowlist and excludes local keys, passwords, databases, backups, caches and prebuilt local web output.

`.github/workflows/verify.yml` runs source tests and container lifecycle checks. Tagging `v<version>` invokes `.github/workflows/release.yml`, which builds, tests the resulting image, then pushes it to GHCR using the workflow token. Set both GHCR packages to public and verify an anonymous pull before advertising the release. GitHub source visibility and package visibility are separate settings. Update the bootstrap version, both launcher manager versions, and default app image for each release. Version 0.1.1 introduces the container manager; do not move the existing 0.1.0 tag.

The image tag is a version label; deploy by digest when immutability is required. Do not overwrite released tags. Release builds publish the exact tested image.

Every release also includes `secretpod-linux-amd64.tar.gz`, `secretpod-manager-linux-amd64.tar.gz`, and their SHA-256 files. Setup automatically uses that public prebuilt archive if the official GHCR tag cannot be pulled. This avoids making registry authentication a prerequisite while package visibility is configured. `docker load -i secretpod-linux-amd64.tar.gz` can preload a verified archive for an offline installation; preload the manager and Caddy as well and use `--no-pull`. The manager must be publicly pullable for first-time online setup; the app has the automatic archive fallback.

## Safe first publication from a working directory

Do not upload a ZIP of a working directory containing a real vault. The source-export tool selects approved source paths and excludes runtime state, developer caches, machine configuration, screenshots and internal work records:

```sh
python3 scripts/export-source.py --output /path/to/new-source-export
```

Review its sibling manifest and every staged path. Run a secret scanner such as Gitleaks against the export before initializing/pushing a public repository. The allowlist reduces accidental publication but cannot prove source text contains no secret. Test files contain deliberately synthetic accounts and credentials; never reuse them in real installations. No private runtime files should be supplied to CI or Docker.

For future releases from an established repository, use the reviewed Git history and normal pull-request review; ignored files are not removed from history if previously committed.

## Release validation record

Local verification on 14 October 2026:

- 94 backend tests and 180 Flutter tests passed; workspace analysis reported no issues.
- 21 Python deployment/export tests passed, including private Windows ACLs, unsafe restore rejection, release-archive checksum validation, and read-only image selection for host-authenticated pulls.
- 6 PowerShell and 6 POSIX launcher regression checks passed.
- A clean Windows source copy with an empty package cache installed dependencies, built and served the app, health endpoint, runtime configuration and matching JavaScript. The generated key survived rebuilds.
- The Linux image built from source. Docker lifecycle checks passed verified local TLS, custom-port redirects, synthetic account/secret storage, restart, backup, upgrade to a distinct image, restore under a new origin, failed pull, overwrite refusal, and failed-candidate recovery protection.
- The container manager passed the same maintenance operations through PowerShell on Windows and a POSIX shell on an isolated Linux Docker engine. Python was absent from each launcher's PATH. Checks included paths with spaces, retained launchers, Windows ACLs, Linux user ownership, and host-visible recovery paths.
- Gitleaks 8.30.1 scanned the allowlisted public export and reported no leaks. Runtime keys/data, caches, backups, screenshots and local records were excluded before scanning.

These are application and deployment checks, not a production security audit. Public DNS/ACME issuance was not exercised without an owned deployment hostname.

See the repository's Actions runs for Linux build, source tests, lifecycle checks and image-push evidence. A local lifecycle run can verify local CA trust and HTTP redirects, but cannot validate public ACME issuance without an owned domain pointing to the test host.
