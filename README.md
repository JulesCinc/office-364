# office-364

Collaborative workspace for a school project → self-hosted Nextcloud (with OnlyOffice) + Nextcloud as identity provider.

## Overview

The goal of this project is to give the school a self-hosted, collaborative office suite, as an alternative to proprietary cloud offerings. It runs on a server owned by the school, so the data stays at the school, and it is reachable from outside the school through the school's reverse proxy.

- **Nextcloud**: storage, sharing and collaboration hub for documents.
- **OnlyOffice**: online editing of documents, spreadsheets and presentations, integrated into Nextcloud.
- **Nextcloud as identity provider**: Nextcloud manages the users and groups of the school (students, teachers, administrators) and acts as the identity provider (e.g. via OpenID Connect) for the other services.

Only office documents are accepted (OOXML and ODF formats editable by OnlyOffice, plus PDF).

## Architecture

```
   Students / teachers (browser, inside or outside the school)
                              │ HTTPS
                              ▼
                 ┌──────────────────────────┐
                 │ School reverse proxy     │  public domain name + TLS
                 │ (managed by school IT)   │  (existing, not part of this repo)
                 └────────────┬─────────────┘
                              │ HTTP
   ┌──────────────────────────┼──── school server (Linux + Docker) ────┐
   │                          ▼                                         │
   │             ┌──────────────────────────┐                          │
   │             │  Nextcloud (apache)      │                          │
   │             │  files · sharing · IdP   │                          │
   │             └──┬─────────┬─────────┬───┘                          │
   │                │         │         │ document editing (later)     │
   │                ▼         ▼         ▼                              │
   │           ┌────────┐ ┌───────┐ ┌──────────────────────────┐       │
   │           │MariaDB │ │ Redis │ │ OnlyOffice Document      │       │
   │           │metadata│ │ cache │ │ Server                   │       │
   │           └────────┘ │ locks │ └──────────────────────────┘       │
   │                      └───────┘                                    │
   └────────────────┬───────────────────────────────────────────────────┘
                    │ NFS (user files only)
                    ▼
       ┌──────────────────────────┐
       │ School NFS server        │  (existing, not part of this repo)
       └──────────────────────────┘
```

- **Nextcloud**: official `nextcloud` Docker image (Apache variant).
- **MariaDB**: stores Nextcloud metadata (users, groups, file index, shares, versions). It runs on the local disk of the server, not on NFS.
- **Redis**: memory cache and transactional file locking, needed when several people edit the same document.
- **NFS**: the existing school NFS share holds the Nextcloud data directory (user files). Access rights are enforced by Nextcloud; the NFS export is restricted to the Nextcloud server.
- **Reverse proxy**: the school's existing reverse proxy provides the public domain name and HTTPS. Nextcloud only exposes HTTP to it.

## Documentation

All project documentation lives in [GitHub Issues](https://github.com/JulesCinc/office-364/issues):

- 📌 [Glossary](https://github.com/JulesCinc/office-364/issues/1): the project's domain vocabulary
- Architecture decisions (label [`adr`](https://github.com/JulesCinc/office-364/issues?q=label%3Aadr)):
  - [ADR-0001](https://github.com/JulesCinc/office-364/issues/2): MariaDB as Nextcloud database
  - [ADR-0002](https://github.com/JulesCinc/office-364/issues/3): official Nextcloud image rather than Nextcloud AIO
  - [ADR-0003](https://github.com/JulesCinc/office-364/issues/4): hosted on a school server, reachable from the Internet via the school reverse proxy
  - [ADR-0004](https://github.com/JulesCinc/office-364/issues/5): primary storage on the school NFS share rather than S3
- Prerequisites to obtain from the school IT (label [`prerequis`](https://github.com/JulesCinc/office-364/issues?q=label%3Aprerequis)):
  - [#6](https://github.com/JulesCinc/office-364/issues/6): NFS export restricted to the Nextcloud server
  - [#7](https://github.com/JulesCinc/office-364/issues/7): reverse proxy and public domain name

## Roadmap

1. [Step 1](https://github.com/JulesCinc/office-364/issues/8): deploy Nextcloud with MariaDB and Redis on the school server
2. Add the OnlyOffice Document Server and its Nextcloud connector
3. Configure Nextcloud as identity provider (OpenID Connect)

## Status

🚧 Work in progress: this repository is being set up as part of the *Intro to Cloud* course.
