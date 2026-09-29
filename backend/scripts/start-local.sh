#!/usr/bin/env bash
# Run the API and reminder jobs together for local mobile development.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

if [[ ! -x .venv/bin/python ]]; then
    echo "Create .venv and install requirements.lock first (see LOCAL_SETUP.md)." >&2
    exit 1
fi
mkdir -p .local

# Fail before starting any background processes if a dependency is unavailable.
.venv/bin/python - <<'CHECK'
import socket
from redis import Redis
from app.core.config import get_settings

settings = get_settings()
if settings.app_env != "development":
    raise SystemExit("This launcher requires APP_ENV=development.")
for url in (settings.redis_url, settings.rate_limit_redis_url,
            settings.celery_broker_url, settings.celery_result_backend):
    with Redis.from_url(url, socket_connect_timeout=2, socket_timeout=2) as client:
        client.ping()
with socket.socket() as listener:
    listener.bind(("0.0.0.0", 8000))
print("Redis is reachable; port 8000 is available.")
CHECK
.venv/bin/alembic upgrade head

children=()
cleanup() {
    trap - EXIT
    if (( ${#children[@]} )); then
        kill "${children[@]}" 2>/dev/null || true
        for child in "${children[@]}"; do
            wait "$child" 2>/dev/null || true
        done
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

.venv/bin/celery -A app.workers.celery_app:celery_app worker \
    --pool=solo --concurrency=1 --loglevel=info --hostname=flow-mobile-local@%h \
    >> .local/worker.log 2>&1 &
children+=("$!")
.venv/bin/celery -A app.workers.celery_app:celery_app beat --loglevel=info \
    >> .local/beat.log 2>&1 &
children+=("$!")
.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 \
    >> .local/api.log 2>&1 &
children+=("$!")

echo "API starting at http://localhost:8000; docs at http://localhost:8000/docs"
echo "Login codes: tail -f $PWD/.local/api.log"
echo "Press Ctrl+C to stop the API and background jobs."
# Stop the other processes if any service exits.
wait -n "${children[@]}"
