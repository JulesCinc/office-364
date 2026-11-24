# office-364

Collaborative workspace for a school project → Local Nextcloud (with OnlyOffice) + Nextcloud as identity provider.

## Overview

The goal of this project is to give the school a self-hosted, collaborative office suite, running locally, as an alternative to proprietary cloud offerings.

- **Nextcloud**: file storage, sharing, calendar, contacts and collaboration hub.
- **OnlyOffice**: online editing of documents, spreadsheets and presentations, integrated into Nextcloud.
- **Nextcloud as identity provider**: Nextcloud manages the users and groups of the association and acts as the identity provider (e.g. via OpenID Connect) for the other services.

## Architecture

```
                 ┌──────────────────────────┐
   Members ────▶ │        Nextcloud         │
  (browser)      │  files · sharing · IdP   │
                 └────────────┬─────────────┘
                              │ document editing
                              ▼
                 ┌──────────────────────────┐
                 │   OnlyOffice Document    │
                 │          Server          │
                 └──────────────────────────┘
```

- Users authenticate once against Nextcloud.
- Nextcloud delegates document editing to the OnlyOffice Document Server.
- Other services can rely on Nextcloud for authentication (single sign-on).

## Status

🚧 Work in progress — this repository is being set up as part of the *Intro to Cloud* course.

