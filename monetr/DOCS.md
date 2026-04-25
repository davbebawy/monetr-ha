# monetr add-on

## Overview

This add-on runs [monetr](https://github.com/monetr/monetr) using the same binary as [ghcr.io/monetr/monetr](https://github.com/monetr/monetr/pkgs/container/monetr). Options from the Home Assistant UI are turned into monetr environment variables. monetr data under `/etc/monetr` is stored on the add-on’s persistent volume (`/data/monetr_etc`).

This packaging follows the same repository layout style as [alexbelgium/hassio-addons](https://github.com/alexbelgium/hassio-addons) (root `repository.json`, one folder per add-on, `config.yaml`, `DOCS.md`, and Dockerfile).

## Bundled PostgreSQL and Valkey (`bundle_services`)

When **bundle_services** is enabled (default), the container starts:

- **PostgreSQL** (data in `/data/postgres`)
- **Valkey** (data in `/data/valkey`)
- **monetr** pointed at `127.0.0.1` for both

You only need to set **`pg_password`** (and optionally change **`pg_database`**). **`pg_username`** must stay **`postgres`** in bundled mode (same as upstream examples).

Expect higher **RAM** use than monetr alone (database + cache in one add-on). AppArmor is disabled for this add-on because bundled database servers do not ship with a tailored profile.

## External services (`bundle_services` off)

Disable **bundle_services** if you already run PostgreSQL and Valkey/Redis elsewhere (for example other add-ons). Then set **`pg_address`**, credentials, and **`redis_address`** when cache is enabled. See [Add-on communication](https://developers.home-assistant.io/docs/add-ons/communication) for internal hostnames.

## Official monetr Docker settings

The official [monetr Docker documentation](https://monetr.app/documentation/install/docker) starts monetr with PostgreSQL, Valkey, `serve --migrate --generate-certificates`, and a persistent `/etc/monetr` volume. This add-on mirrors that flow in one container for Home Assistant.

Set **`server_external_url`** when you access monetr through a domain, reverse proxy, or Home Assistant URL other than `localhost:4000`. monetr uses this value for auth cookies and links, matching the documented `MONETR_SERVER_EXTERNAL_URL` setting.

Use **`env_vars`** for advanced monetr settings that are not first-class add-on options yet, such as Plaid, email, Sentry, or other documented `MONETR_*` environment variables.

## Other options

| Option | Meaning |
|--------|---------|
| server_external_url | Sets `MONETR_SERVER_EXTERNAL_URL` when provided. |
| migrate_on_start | Adds `--migrate` to `monetr serve`. |
| generate_certificates | Adds `--generate-certificates` (first-run TLS under Monetr’s config dir). |

## Upgrading monetr

Match **`version`** in `config.yaml` to the add-on release and **`MONETR_VERSION`** in `Dockerfile` to the upstream monetr image tag, then rebuild or reinstall the add-on.

## Notes from monetr's Docker docs

- monetr recommends Docker Compose as the simplest supported install path; this add-on follows that service layout inside Home Assistant.
- Container image tags are versioned (for example `1.13.0`) and do **not** include the `v` prefix.
- The standard compose stack starts Monetr with `serve --migrate --generate-certificates`, which this add-on mirrors via `migrate_on_start` and `generate_certificates`.
