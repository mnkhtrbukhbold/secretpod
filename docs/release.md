# Release and public-source workflow

Repository: https://github.com/mnkhtrbukhbold/secretpod

Image: `ghcr.io/mnkhtrbukhbold/secretpod:<version>` (Linux amd64).

## Build and test

```sh
docker build -t secretpod:test .
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tests/docker_lifecycle.py --image secretpod:test
```

The Docker build installs the pinned Flutter toolchain, resolves the committed lockfile, builds web assets, and compiles the backend/native assets. The final image runs as UID/GID 10001. Its context uses an allowlist and excludes local keys, passwords, databases, backups, caches and prebuilt local web output.

`.github/workflows/verify.yml` runs source tests and container lifecycle checks. Tagging `v<version>` invokes `.github/workflows/release.yml`, which builds, tests the resulting image, then pushes it to GHCR using the workflow token. Set the GHCR package to public and verify an anonymous pull before advertising the release. GitHub source visibility and package visibility are separate settings. Update the bootstrap version and default image in the management tool for each release.

The image tag is a version label; deploy by digest when immutability is required. Do not overwrite released tags. Release builds publish the exact tested image.

## Safe first publication from a working directory

Do not upload a ZIP of a working directory containing a real vault. The source-export tool selects approved source paths and excludes runtime state, developer caches, machine configuration, screenshots and internal work records:

```sh
python3 scripts/export-source.py --output /path/to/new-source-export
```

Review its sibling manifest and every staged path. Run a secret scanner such as Gitleaks against the export before initializing/pushing a public repository. The allowlist reduces accidental publication but cannot prove source text contains no secret. Test files contain deliberately synthetic accounts and credentials; never reuse them in real installations. No private runtime files should be supplied to CI or Docker.

For future releases from an established repository, use the reviewed Git history and normal pull-request review; ignored files are not removed from history if previously committed.

## Release validation record

See the repository's Actions runs for Linux build, source tests, lifecycle checks and image-push evidence. A local lifecycle run can verify local CA trust and HTTP redirects, but cannot validate public ACME issuance without an owned domain pointing to the test host.
