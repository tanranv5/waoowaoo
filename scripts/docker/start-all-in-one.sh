#!/usr/bin/env bash

set -euo pipefail

readonly MYSQL_DATA_DIR="/app/data/mysql"
readonly MYSQL_SOCKET="/run/mysqld/mysqld.sock"
readonly MYSQL_PORT="3306"
readonly REDIS_DATA_DIR="/app/data/redis"
readonly REDIS_PORT="6379"
readonly WAIT_LIMIT_SECONDS="90"

MYSQL_PID=""
REDIS_PID=""

set_defaults() {
  : "${MYSQL_DATABASE:=waoowaoo}"
  : "${MYSQL_USER:=waoowaoo}"
  : "${MYSQL_PASSWORD:=waoowaoo123}"
  : "${MYSQL_ROOT_PASSWORD:=waoowaoo-root-123}"
  : "${DATABASE_URL:=mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@127.0.0.1:${MYSQL_PORT}/${MYSQL_DATABASE}}"
  : "${REDIS_HOST:=127.0.0.1}"
  : "${REDIS_PORT:=${REDIS_PORT}}"
  : "${REDIS_USERNAME:=}"
  : "${REDIS_PASSWORD:=}"
  : "${REDIS_TLS:=}"
  : "${APP_START_MODE:=full}"
  export MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD MYSQL_ROOT_PASSWORD
  export DATABASE_URL REDIS_HOST REDIS_PORT REDIS_USERNAME REDIS_PASSWORD REDIS_TLS APP_START_MODE
}

prepare_dirs() {
  mkdir -p "${MYSQL_DATA_DIR}" "${REDIS_DATA_DIR}" /app/logs /run/mysqld
  chown -R mysql:mysql "${MYSQL_DATA_DIR}" /run/mysqld
}

init_mysql_if_needed() {
  if [ -d "${MYSQL_DATA_DIR}/mysql" ]; then
    return
  fi
  mariadb-install-db --user=mysql --datadir="${MYSQL_DATA_DIR}" --skip-test-db >/app/logs/mysql-init.log 2>&1
}

start_mysql() {
  mariadbd \
    --user=mysql \
    --datadir="${MYSQL_DATA_DIR}" \
    --socket="${MYSQL_SOCKET}" \
    --pid-file=/run/mysqld/mysqld.pid \
    --bind-address=127.0.0.1 \
    --port="${MYSQL_PORT}" \
    --skip-name-resolve \
    --default-authentication-plugin=mysql_native_password \
    --sql_mode=STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION \
    >/app/logs/mysql.log 2>&1 &
  MYSQL_PID="$!"
}

wait_mysql() {
  local second
  for second in $(seq 1 "${WAIT_LIMIT_SECONDS}"); do
    if mariadb-admin --socket="${MYSQL_SOCKET}" ping >/dev/null 2>&1; then
      return
    fi
    if ! kill -0 "${MYSQL_PID}" 2>/dev/null; then
      echo "MySQL process exited unexpectedly."
      return 1
    fi
    sleep 1
  done
  echo "MySQL startup timeout after ${WAIT_LIMIT_SECONDS}s."
  return 1
}

configure_mysql() {
  mariadb --socket="${MYSQL_SOCKET}" -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL
}

start_redis() {
  redis-server \
    --bind 127.0.0.1 \
    --port "${REDIS_PORT}" \
    --appendonly yes \
    --dir "${REDIS_DATA_DIR}" \
    >/app/logs/redis.log 2>&1 &
  REDIS_PID="$!"
}

wait_redis() {
  local second
  for second in $(seq 1 "${WAIT_LIMIT_SECONDS}"); do
    if redis-cli -h 127.0.0.1 -p "${REDIS_PORT}" ping | grep -q PONG; then
      return
    fi
    if ! kill -0 "${REDIS_PID}" 2>/dev/null; then
      echo "Redis process exited unexpectedly."
      return 1
    fi
    sleep 1
  done
  echo "Redis startup timeout after ${WAIT_LIMIT_SECONDS}s."
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

run_app() {
  npx prisma db push --skip-generate
  if [ "${APP_START_MODE}" = "services_only" ]; then
    tail -f /dev/null
    return
  fi
  npm run start
}

main() {
  trap cleanup INT TERM EXIT
  set_defaults
  prepare_dirs
  init_mysql_if_needed
  start_mysql
  wait_mysql
  configure_mysql
  start_redis
  wait_redis
  run_app
}

main
