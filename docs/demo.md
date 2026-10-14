# Public browser demo

The demo runs the SecretPod interface with a synthetic dataset stored in the
visitor's browser. It has no API server, database service, volume, encryption key,
email delivery, or connection to a production vault. It is an interactive product
demonstration, not secure storage. Enter only invented values: demo values are
readable through browser storage and developer tools.

The dataset is maintained as source in
`secretpod/secretpod_flutter/lib/demo/demo_seed.dart` on `main`. The demo entrypoint
is `lib/main_demo.dart`; the normal application still starts from `lib/main.dart`.
The seed contains invented accounts, organizations, projects, members, invitations,
secrets, and activity. The names, values, and implementation are public and can be
read from the repository or downloaded JavaScript. No binary vault or local user
database belongs in a demo build.

The initial sample includes two organizations, nine projects, six accounts,
36 secrets, 157 activity entries, and nine invitations (pending, declined,
expired, accepted, and revoked). Use **Sample invitation** in the demo banner
to obtain the fictional owner's incoming invitation link, then accept it under
**Account → My invitations**. Accepting it adds a third organization to this
browser's demo. Expired sample links can be restored with **Reset demo**.

## Browser data and reset

On the first visit, the app copies the bundled seed into browser local storage.
Edits survive page reloads and are local to that browser profile and site origin.
Tabs on the same origin share the saved demo; separate browsers and domains do not.
Use a current browser with local storage and Web Locks enabled over HTTPS or
`localhost`.

**Reset demo** discards changes and reloads the seed bundled with the currently
loaded app. A deployment or ordinary page reload does not reset existing demo
data. After publishing a changed seed, reload the page to get the new code, then
choose **Reset demo** to load the updated examples. Clearing this site's browser
data also causes the seed to be loaded on the next visit. An unreadable or
incompatible saved dataset requires an explicit reset; the app does not silently
erase it or fall back to a live server.

The demo build disables Flutter's generated offline service worker. The web
server sends `Cache-Control: no-store` for the app shell, bootstrap,
executable JavaScript, service-worker file, manifest, and version metadata.
Supporting assets have a one-hour cache lifetime with revalidation. An old service
worker installed by another deployment on the same origin can intercept requests
before they reach the server. If old code persists, remove that site's service
worker and cached site data in browser settings, then reopen the demo; this also
discards the saved demo edits.

## Build and run locally

Run from the repository root so Docker uses the source allowlist in
`.dockerignore`:

```sh
docker build --file deploy/demo.Dockerfile --tag secretpod-demo .
docker run --rm --publish 8080:8080 secretpod-demo
```

Open `http://localhost:8080`; `http://localhost:8080/healthz` returns `ok`. To test
the port supplied by a hosting platform:

```sh
docker run --rm --env PORT=8091 --publish 8091:8091 secretpod-demo
```

The build pins the same Flutter revision as the production Dockerfile and uses:

```sh
flutter build web --release --no-web-resources-cdn --target lib/main_demo.dart --pwa-strategy=none
```

Only the compiled web assets and Caddy configuration are copied to the runtime
image. The container serves HTTP on `PORT`, defaulting to `8080`; the hosting
platform terminates public HTTPS. Keep the source allowlist intact and never add
real credentials, runtime databases, backups, or generated local web output to the
image context.

## Deploy the demo branch to Railway

Keep shared demo code, the synthetic seed, and `deploy/demo.*` on `main`, where the
root `Dockerfile` remains the production server build. On the separate `demo`
branch, copy `deploy/demo.Dockerfile` to the root `Dockerfile`. Railway detects that
root file automatically and builds the static demo without a `railway.toml` file.
When merging future changes from `main` into `demo`, retain the demo version of
the root `Dockerfile` and synchronize it with `deploy/demo.Dockerfile` before
redeploying. Do not merge that branch-specific root file back into `main`.

Configure one Railway service with these settings:

| Setting | Value |
| --- | --- |
| Source branch | `demo` |
| Root directory / build context | Repository root |
| Builder | Dockerfile |
| Dockerfile path | Root `Dockerfile` copied from `deploy/demo.Dockerfile` |
| Start command | Use the Dockerfile command |
| Service variable | `PORT=8080` |
| Public domain target port | `8080` |
| Healthcheck path | `/healthz` |
| Healthcheck timeout | 60 seconds |
| Replicas | 1 |
| Database, volumes, credentials | None |

Set `/healthz` as the healthcheck path in the service's deployment settings, then
generate a Railway public domain targeting port `8080`. Caddy accepts the hostname
used by Railway healthchecks. Railway uses the health endpoint during deployment,
not as ongoing uptime monitoring. See
[Railway healthchecks](https://docs.railway.com/deployments/healthchecks).

Railway's service UI, checked on 2026-10-14, states that new services cannot opt
into the legacy configuration-file format since 2026-08-28. This deployment uses
automatic root-Dockerfile detection and service settings. Existing legacy
configurations have a separate migration deadline; see Railway's
[configuration reference](https://docs.railway.com/config-as-code/reference).

The Railway CLI can manage deployments after `railway login` and `railway link`.
Once the `demo` branch has been pushed, connect it with
`railway service source connect --repo mnkhtrbukhbold/secretpod --branch demo`.
For subsequent manual releases, use `railway redeploy --from-source --yes`;
`railway service status` and `railway logs` show the deployment result.

## Verify before publishing

The focused container tests exercise the actual Caddy configuration with invented
static fixtures. They cover the default and overridden ports, the Railway
healthcheck host, deep links, cache headers, and missing assets. They do not build
Flutter or test the application's browser interactions.

```powershell
$env:SECRETPOD_DEMO_CONTAINER_TEST = '1'
python -m unittest discover -s tests -p 'test_demo_packaging.py' -v
```

Also build the complete demo image and check it in a browser: edit a synthetic
record, reload to verify persistence, then reset to verify seed restoration. Check
the same behavior and `/healthz` on the public Railway domain. A working container
healthcheck alone does not prove the Flutter application loads or its interactions
work.
