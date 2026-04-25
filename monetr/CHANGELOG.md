# Changelog

## 1.13.0

- Bundle PostgreSQL and Valkey in the same container (optional; default on), similar to running monetr's compose stack in one add-on.
- Align repository metadata with common community patterns ([alexbelgium/hassio-addons](https://github.com/alexbelgium/hassio-addons): `repository.json`, `panel_icon`, `url`).
- Set `apparmor: false` for bundled database workloads.
- Align with monetr Docker docs by bundling Valkey and documenting pinned version-tag behavior.
- Add `server_external_url` and `env_vars` options to map official monetr Docker/config environment variables from Home Assistant.
- Detect the packaged Valkey service user at startup instead of assuming `redis:redis`.
