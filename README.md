# monetr Home Assistant Add-on

Home Assistant add-on repository for [monetr](https://github.com/monetr/monetr), structured like community stores such as [alexbelgium/hassio-addons](https://github.com/alexbelgium/hassio-addons): root `repository.json`, one folder per add-on, `config.yaml` + `Dockerfile` + `DOCS.md`.

[![Open your Home Assistant instance and show the add add-on repository dialog with this repository pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fdavidbebawy%2Fmonetr-ha)

## Bundled stack (default)

With **`bundle_services`** left on (default), a single install runs **PostgreSQL**, **Valkey**, and **monetr** together, matching monetr's official [Docker Compose installation](https://monetr.app/documentation/install/docker). Set **`pg_password`** in the UI; keep **`pg_username`** as **`postgres`** in bundled mode.

Turn **`bundle_services`** off if you want to point Monetr at your own Postgres and Valkey/Redis.

Set **`server_external_url`** if you access monetr through anything other than `localhost:4000`; monetr uses this value for auth cookies and generated links.

## Install

1. **Settings → Add-ons → Add-on store** (or **Apps**) → **⋮ → Repositories**.
2. Add `https://github.com/davidbebawy/monetr-ha`, save, then install **monetr**.

The repository metadata follows the common alexbelgium pattern (`name`, `udev`, `url`, `maintainer`) so Home Assistant can add the repo directly.

## monetr version

Keep **`version`** in `monetr/config.yaml` aligned with the add-on release and **`MONETR_VERSION`** in `monetr/Dockerfile` aligned with the tag from [ghcr.io/monetr/monetr](https://github.com/monetr/monetr/pkgs/container/monetr).

monetr's official docs recommend using pinned version tags and note that image tags omit the `v` prefix from release versions; for example release `v1.13.0` uses image tag `1.13.0`.

## Custom / extended monetr image

Point the `FROM ghcr.io/monetr/monetr:…` stage in `monetr/Dockerfile` at your image, keep `io.hass.*` labels in sync with `config.yaml` `version`, and extend `entrypoint.sh` / options as needed.
