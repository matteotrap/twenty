#!/bin/sh
set -e

if [ "${1:-}" = "worker" ]; then
  shift
  export DISABLE_DB_MIGRATIONS=true
  export DISABLE_CRON_JOBS_REGISTRATION=true
  set -- yarn worker:prod
else
  export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=1536}"
fi

exec /app/entrypoint.sh "$@"
