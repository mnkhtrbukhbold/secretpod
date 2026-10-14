# SecretPod development

SecretPod is a self-hostable team secrets manager with a Flutter frontend and a Serverpod backend, both written in Dart. For local setup, see the [README](../README.md).

## Main features

- Store encrypted credentials, organized by project and environment.
- Manage organizations, invitations, member roles, and project permissions.
- Disable, restore, or remove member access and flag credentials for rotation.
- Manage accounts, profiles, and sessions through a responsive interface with light and dark themes.

## Modules

| Package | Purpose |
| --- | --- |
| `secretpod_flutter` | Flutter interface, application state, and API integration. |
| `secretpod_server` | Serverpod endpoints, business logic, and persistence. |
| `secretpod_client` | Generated Dart client and models shared with the frontend. |

The packages live under `secretpod/`.

### Backend

Within `secretpod_server/lib/src/`:

- `account/`: accounts, authentication, profiles, and sessions.
- `organization/` and `invitation/`: teams, membership, invitations, and access permissions.
- `vault/` and `crypto/`: secret management and encryption.
- `storage/`: SQLite persistence and migrations.
- `tracking/`: activity history.
- `endpoints/` and `models/`: API operations and model definitions used by Serverpod code generation.
- `deployment/` and `web/`: deployment support and web routes.

### Frontend

Within `secretpod_flutter/lib/`:

- `screens/`: workspace, account, and team management screens and dialogs.
- `state/`: session and workspace state, API calls, and display preferences.
- `widgets/` and `theme/`: shared interface components and styling.
- `config/`: application configuration.

Edit endpoints and model definitions rather than generated protocol files. Package tests live in each package's `test/` directory.
