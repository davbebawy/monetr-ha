#!/bin/bash
set -euo pipefail

OPTIONS=/data/options.json
mkdir -p /data/monetr_etc

if [ ! -L /etc/monetr ]; then
  rm -rf /etc/monetr
  ln -s /data/monetr_etc /etc/monetr
fi

chown -h monetr:monetr /etc/monetr
chown -R monetr:monetr /data/monetr_etc

if [ ! -f "$OPTIONS" ]; then
  echo "Missing ${OPTIONS}" >&2
  exit 1
fi

bundle_services="$(jq -r '.bundle_services' "$OPTIONS")"
server_external_url="$(jq -r '.server_external_url // empty' "$OPTIONS")"
pg_address="$(jq -r '.pg_address // empty' "$OPTIONS")"
pg_port="$(jq -r '.pg_port // 5432' "$OPTIONS")"
pg_username="$(jq -r '.pg_username // empty' "$OPTIONS")"
pg_password="$(jq -r '.pg_password // empty' "$OPTIONS")"
pg_database="$(jq -r '.pg_database // empty' "$OPTIONS")"
redis_address="$(jq -r '.redis_address // empty' "$OPTIONS")"
redis_enabled="$(jq -r '.redis_enabled' "$OPTIONS")"
allow_sign_up="$(jq -r '.allow_sign_up' "$OPTIONS")"
storage_enabled="$(jq -r '.storage_enabled' "$OPTIONS")"
storage_provider="$(jq -r '.storage_provider // "filesystem"' "$OPTIONS")"
migrate_on_start="$(jq -r '.migrate_on_start' "$OPTIONS")"
generate_certificates="$(jq -r '.generate_certificates' "$OPTIONS")"

export BUNDLE_SERVICES="$bundle_services"
PGDATA=/data/postgres
PG_BIN=""
PG_CTL=""

sql_escape_literal() {
  printf '%s' "$1" | sed "s/'/''/g"
}

find_pg_bin() {
  local d
  for d in /usr/lib/postgresql/*/bin; do
    if [ -x "$d/initdb" ]; then
      printf '%s' "$d"
      return 0
    fi
  done
  return 1
}

apply_custom_env_vars() {
  local name value
  while IFS='=' read -r name value; do
    if [ -z "$name" ]; then
      continue
    fi
    if ! printf '%s' "$name" | grep -qE '^[A-Za-z0-9_]+$'; then
      echo "Skipping invalid env var name: ${name}" >&2
      continue
    fi
    export "${name}=${value}"
  done < <(jq -r '.env_vars[]? | select(.name != null) | "\(.name)=\(.value // "")"' "$OPTIONS")
}

start_bundled_postgres() {
  PG_BIN="$(find_pg_bin)" || {
    echo "PostgreSQL binaries not found in image." >&2
    exit 1
  }
  PG_CTL="${PG_BIN}/pg_ctl"
  export PGDATA

  mkdir -p "$PGDATA"
  chown postgres:postgres "$PGDATA"

  if [ ! -f "$PGDATA/PG_VERSION" ]; then
    sudo -u postgres "${PG_BIN}/initdb" -D "$PGDATA" -E UTF8 --locale=C.UTF-8 --auth-local=peer --auth-host=scram-sha-256
    grep -q "127.0.0.1/32" "$PGDATA/pg_hba.conf" || \
      echo "host all all 127.0.0.1/32 scram-sha-256" >> "$PGDATA/pg_hba.conf"
  fi

  sudo -u postgres "$PG_CTL" -D "$PGDATA" -w start -t 90 -o "-c listen_addresses=127.0.0.1 -c port=5432 -c unix_socket_directories=$PGDATA"

  until sudo -u postgres "${PG_BIN}/pg_isready" -h 127.0.0.1 -p 5432 >/dev/null 2>&1; do
    sleep 1
  done

  local esc
  esc="$(sql_escape_literal "$pg_password")"
  # Peer auth over the Unix socket (SCRAM on 127.0.0.1 is not usable before a password exists).
  sudo -u postgres psql -h "$PGDATA" -d postgres -c "ALTER USER \"${pg_username}\" PASSWORD '${esc}';" >/dev/null

  if ! sudo -u postgres psql -h "$PGDATA" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='${pg_database}'" | grep -q 1; then
    sudo -u postgres psql -h "$PGDATA" -d postgres -c "CREATE DATABASE \"${pg_database}\" OWNER \"${pg_username}\";" >/dev/null
  fi
}

start_bundled_valkey() {
  mkdir -p /data/valkey
  chown redis:redis /data/valkey
  valkey-server \
    --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir /data/valkey \
    --pidfile /data/valkey/valkey-server.pid

  until valkey-cli -h 127.0.0.1 -p 6379 ping >/dev/null 2>&1; do
    sleep 1
  done
}

cleanup() {
  if [ -n "${MONETR_PID:-}" ] && kill -0 "$MONETR_PID" 2>/dev/null; then
    kill -TERM "$MONETR_PID" 2>/dev/null || true
    wait "$MONETR_PID" 2>/dev/null || true
  fi
  if [ "$bundle_services" = "true" ]; then
    valkey-cli -h 127.0.0.1 -p 6379 shutdown nosave 2>/dev/null || true
    if [ -n "${PG_CTL:-}" ] && [ -d "${PGDATA:-}" ]; then
      sudo -u postgres "$PG_CTL" -D "$PGDATA" stop -m fast 2>/dev/null || true
    fi
  fi
}

trap cleanup EXIT HUP INT QUIT TERM

if [ -z "$pg_password" ]; then
  echo "pg_password is required." >&2
  exit 1
fi

if [ -z "$pg_database" ] || [ -z "$pg_username" ]; then
  echo "pg_username and pg_database are required." >&2
  exit 1
fi

if ! printf '%s' "$pg_database" | grep -qE '^[a-zA-Z0-9_]+$'; then
  echo "pg_database must match ^[a-zA-Z0-9_]+$" >&2
  exit 1
fi

if ! printf '%s' "$pg_username" | grep -qE '^[a-zA-Z0-9_]+$'; then
  echo "pg_username must match ^[a-zA-Z0-9_]+$" >&2
  exit 1
fi

if [ "$bundle_services" = "true" ]; then
  if [ "$pg_username" != "postgres" ]; then
    echo "Bundled mode currently expects pg_username=postgres (matches upstream defaults)." >&2
    exit 1
  fi
  start_bundled_postgres
  if [ "$redis_enabled" = "true" ]; then
    start_bundled_valkey
  fi
  export MONETR_PG_ADDRESS="127.0.0.1"
  export MONETR_PG_PORT="5432"
  export MONETR_PG_USERNAME="$pg_username"
  export MONETR_PG_PASSWORD="$pg_password"
  export MONETR_PG_DATABASE="$pg_database"
else
  if [ -z "$pg_address" ]; then
    echo "With bundle_services disabled, pg_address is required." >&2
    exit 1
  fi
  export MONETR_PG_ADDRESS="$pg_address"
  export MONETR_PG_USERNAME="$pg_username"
  export MONETR_PG_PASSWORD="$pg_password"
  export MONETR_PG_DATABASE="$pg_database"
  if [ -n "$pg_port" ] && [ "$pg_port" != "null" ]; then
    export MONETR_PG_PORT="$pg_port"
  fi
fi

export MONETR_REDIS_ENABLED="$redis_enabled"
export MONETR_ALLOW_SIGN_UP="$allow_sign_up"
export MONETR_STORAGE_ENABLED="$storage_enabled"
export MONETR_STORAGE_PROVIDER="$storage_provider"

if [ -n "$server_external_url" ]; then
  export MONETR_SERVER_EXTERNAL_URL="$server_external_url"
fi

if [ "$redis_enabled" = "true" ]; then
  if [ "$bundle_services" = "true" ]; then
    export MONETR_REDIS_ADDRESS="127.0.0.1"
  else
    if [ -z "$redis_address" ]; then
      echo "redis_address is required when redis_enabled and bundle_services are false." >&2
      exit 1
    fi
    export MONETR_REDIS_ADDRESS="$redis_address"
  fi
else
  unset MONETR_REDIS_ADDRESS 2>/dev/null || true
fi

apply_custom_env_vars

cmd=(/usr/bin/monetr serve)

if [ "$migrate_on_start" = "true" ]; then
  cmd+=(--migrate)
fi

if [ "$generate_certificates" = "true" ]; then
  cmd+=(--generate-certificates)
fi

runuser -u monetr -- "${cmd[@]}" &
MONETR_PID=$!
wait "$MONETR_PID"
exit "$?"
