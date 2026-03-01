#!/usr/bin/env bash

set -euo pipefail

readonly MYSQL_DATA_DIR="/app/data/mysql"
readonly REDIS_DATA_DIR="/app/data/redis"
readonly MYSQL_INTERNAL_PORT="3306"
readonly REDIS_INTERNAL_PORT="6379"
readonly SERVICE_WAIT_SECONDS="60"

MYSQL_PID=""
REDIS_PID=""

set_default_env() {
  : "${MYSQL_DATABASE:=waoowaoo}"
  : "${MYSQL_USER:=waoowaoo}"
  : "${MYSQL_PASSWORD:=waoowaoo123}"
  : "${MYSQL_ROOT_PASSWORD:=waoowaoo-root-123}"
  : "${MYSQL_ROOT_HOST:=%}"
  : "${DATABASE_URL:=mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@127.0.0.1:${MYSQL_INTERNAL_PORT}/${MYSQL_DATABASE}}"
  : "${REDIS_HOST:=127.0.0.1}"
  : "${REDIS_PORT:=${REDIS_INTERNAL_PORT}}"
  : "${REDIS_USERNAME:=}"
  : "${REDIS_PASSWORD:=}"
  : "${REDIS_TLS:=}"
  : "${STORAGE_TYPE:=local}"
  : "${NEXTAUTH_URL:=http://localhost:3000}"
  : "${NEXTAUTH_SECRET:=waoowaoo-default-secret-2026}"
  : "${CRON_SECRET:=waoowaoo-docker-cron-secret}"
  : "${INTERNAL_TASK_TOKEN:=waoowaoo-docker-task-token}"
  : "${API_ENCRYPTION_KEY:=waoowaoo-opensource-fixed-key-2026}"
  : "${WATCHDOG_INTERVAL_MS:=30000}"
  : "${TASK_HEARTBEAT_TIMEOUT_MS:=90000}"
  : "${QUEUE_CONCURRENCY_IMAGE:=50}"
  : "${QUEUE_CONCURRENCY_VIDEO:=50}"
  : "${QUEUE_CONCURRENCY_VOICE:=20}"
  : "${QUEUE_CONCURRENCY_TEXT:=50}"
  : "${BULL_BOARD_HOST:=0.0.0.0}"
  : "${BULL_BOARD_PORT:=3010}"
  : "${BULL_BOARD_BASE_PATH:=/admin/queues}"
  : "${BULL_BOARD_USER:=}"
  : "${BULL_BOARD_PASSWORD:=}"
  : "${LOG_UNIFIED_ENABLED:=true}"
  : "${LOG_LEVEL:=INFO}"
  : "${LOG_FORMAT:=json}"
  : "${LOG_DEBUG_ENABLED:=false}"
  : "${LOG_AUDIT_ENABLED:=true}"
  : "${LOG_SERVICE:=waoowaoo}"
  : "${LOG_REDACT_KEYS:=password,token,apiKey,apikey,authorization,cookie,secret,access_token,refresh_token}"
  : "${BILLING_MODE:=OFF}"
  : "${LLM_STREAM_EPHEMERAL_ENABLED:=true}"
  export MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD MYSQL_ROOT_PASSWORD MYSQL_ROOT_HOST
  export DATABASE_URL REDIS_HOST REDIS_PORT REDIS_USERNAME REDIS_PASSWORD REDIS_TLS
}

prepare_dirs() {
  mkdir -p "${MYSQL_DATA_DIR}" "${REDIS_DATA_DIR}" /app/logs
}

start_mysql() {
  /usr/local/bin/docker-entrypoint.sh mysqld \
    --datadir="${MYSQL_DATA_DIR}" \
    --bind-address=127.0.0.1 \
    --port="${MYSQL_INTERNAL_PORT}" \
    --default-authentication-plugin=mysql_native_password \
    --sql_mode=STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION \
    >/app/logs/mysql.log 2>&1 &
  MYSQL_PID="$!"
}

wait_mysql() {
  local second
  for second in $(seq 1 "${SERVICE_WAIT_SECONDS}"); do
    if mysqladmin ping -h 127.0.0.1 -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" >/dev/null 2>&1; then
      return
    fi
    if ! kill -0 "${MYSQL_PID}" 2>/dev/null; then
      echo "MySQL process exited unexpectedly."
      return 1
    fi
    sleep 1
  done
  echo "MySQL startup timeout after ${SERVICE_WAIT_SECONDS}s."
  return 1
}

start_redis() {
  redis-server \
    --bind 127.0.0.1 \
    --port "${REDIS_INTERNAL_PORT}" \
    --appendonly yes \
    --dir "${REDIS_DATA_DIR}" \
    >/app/logs/redis.log 2>&1 &
  REDIS_PID="$!"
}

wait_redis() {
  local second
  for second in $(seq 1 "${SERVICE_WAIT_SECONDS}"); do
    if redis-cli -h 127.0.0.1 -p "${REDIS_INTERNAL_PORT}" ping | grep -q "PONG"; then
      return
    fi
    if ! kill -0 "${REDIS_PID}" 2>/dev/null; then
      echo "Redis process exited unexpectedly."
      return 1
    fi
    sleep 1
  done
  echo "Redis startup timeout after ${SERVICE_WAIT_SECONDS}s."
  return 1
}

cleanup() {
  if [ -n "${REDIS_PID}" ] && kill -0 "${REDIS_PID}" 2>/dev/null; then
    kill "${REDIS_PID}"
    wait "${REDIS_PID}" || true
  fi
  if [ -n "${MYSQL_PID}" ] && kill -0 "${MYSQL_PID}" 2>/dev/null; then
    kill "${MYSQL_PID}"
    wait "${MYSQL_PID}" || true
  fi
}

handle_signal() {
  cleanup
  exit 0
}

print_banner() {
  sleep 5
  echo ''
  echo '╔══════════════════════════════════════════════════╗'
  echo '║            waoowaoo is ready!                   ║'
  echo '║                                                  ║'
  echo '║  HTTP:  http://localhost:13000                  ║'
  echo '║                                                  ║'
  echo '║  For HTTPS, run Caddy on host:                  ║'
  echo '║  caddy run --config Caddyfile                   ║'
  echo '║  Then open: https://localhost:1443              ║'
  echo '╚══════════════════════════════════════════════════╝'
  echo ''
}

main() {
  trap handle_signal INT TERM
  set_default_env
  prepare_dirs
  start_mysql
  wait_mysql
  start_redis
  wait_redis
  npx prisma db push --skip-generate
  print_banner &
  npm run start
}

main
