#!/usr/bin/env bash
# Boots the image against a throwaway Postgres and waits for GET /health to report healthy (it runs
# the Postgres health check). That proves the released binaries start on this runtime, bind their
# config and reach the database — the things a runtime bump can break. Keycloak and the OTLP
# collector only get placeholder settings: they're required config, but nothing calls them to boot.
#
#   scripts/smoke-test.sh <image>
set -euo pipefail

IMAGE=${1:?usage: smoke-test.sh <image>}
NAME=backend-smoke-$$
PORT=${SMOKE_PORT:-18080}

cleanup() {
  docker rm -f "$NAME-api" "$NAME-pg" >/dev/null 2>&1 || true
  docker network rm "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$NAME" >/dev/null
docker run -d --name "$NAME-pg" --network "$NAME" --network-alias postgres \
  -e POSTGRES_PASSWORD=smoke postgres:17 >/dev/null
until docker exec "$NAME-pg" pg_isready -U postgres -h 127.0.0.1 >/dev/null 2>&1; do sleep 1; done

DB="Host=postgres;Database=postgres;Username=postgres;Password=smoke"
db_env=()
for module in Account Character Banking Company Item Shop Phone World Shared; do
  db_env+=(-e "ConnectionStrings__${module}Database=$DB")
done

docker run -d --name "$NAME-api" --network "$NAME" -p "127.0.0.1:$PORT:8080" \
  -e ASPNETCORE_HTTP_PORTS=8080 \
  "${db_env[@]}" \
  -e ConnectionStrings__Tracing=http://otel-collector.invalid:4317 \
  -e Authentication__Authority=https://keycloak.invalid/realms/smoke \
  -e Keycloak__BaseUrl=http://keycloak.invalid/ \
  -e Keycloak__PublicBaseUrl=http://keycloak.invalid/ \
  -e Keycloak__Realm=smoke \
  -e Keycloak__ProvisioningClientId=smoke \
  -e Keycloak__ProvisioningClientSecret=smoke \
  "$IMAGE" >/dev/null

for _ in $(seq 1 60); do
  curl -fs "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  [ "$(docker inspect -f '{{.State.Running}}' "$NAME-api")" = true ] || break
  sleep 2
done
if ! curl -fs "http://127.0.0.1:$PORT/health" >/dev/null; then
  docker logs "$NAME-api" 2>&1 | tail -50
  echo "FAIL: backend did not become healthy" >&2
  exit 1
fi
echo "ok: backend $(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGE" | sed -n 's/^ELIFERPG_BACKEND_VERSION=//p') is healthy on $(docker exec "$NAME-api" dotnet --list-runtimes | grep AspNetCore)"
