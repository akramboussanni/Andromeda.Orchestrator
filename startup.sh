#!/usr/bin/env bash
set -euo pipefail

for bin in curl python3; do
  if ! command -v "${bin}" >/dev/null 2>&1; then
    echo "Missing required binary: ${bin}" >&2
    exit 1
  fi
done

# Required env
: "${CF_API_TOKEN:?CF_API_TOKEN is required}"
: "${CF_ZONE_ID:?CF_ZONE_ID is required}"
: "${CF_RECORD_NAME:?CF_RECORD_NAME is required}"

# Optional env
CF_RECORD_TYPE="${CF_RECORD_TYPE:-A}"            # A or AAAA
CF_PROXIED="${CF_PROXIED:-false}"                # true or false
CF_TTL="${CF_TTL:-120}"                          # 1 for automatic, else 60-86400
ORCH_HOST="${ORCH_HOST:-0.0.0.0}"
ORCH_PORT="${ORCH_PORT:-9000}"
ORCH_MODULE="${ORCH_MODULE:-main:app}"
ORCH_WORKDIR="${ORCH_WORKDIR:-/opt/andromeda-orchestrator}"

# Prefer GCP metadata IP, fallback to ipify
get_public_ip() {
  local ip=""
  ip="$(curl -fsS -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" || true)"
  if [[ -z "${ip}" ]]; then
    ip="$(curl -fsS https://api.ipify.org || true)"
  fi
  if [[ -z "${ip}" ]]; then
    echo "Failed to resolve public IP" >&2
    exit 1
  fi
  echo "${ip}"
}

PUBLIC_IP="$(get_public_ip)"
echo "Resolved public IP: ${PUBLIC_IP}"

CF_API="https://api.cloudflare.com/client/v4"
AUTH_HEADER="Authorization: Bearer ${CF_API_TOKEN}"
JSON_HEADER="Content-Type: application/json"

# Find existing record
RESP="$(curl -fsS -X GET \
  "${CF_API}/zones/${CF_ZONE_ID}/dns_records?type=${CF_RECORD_TYPE}&name=${CF_RECORD_NAME}" \
  -H "${AUTH_HEADER}")"

RECORD_ID="$(echo "${RESP}" | python3 -c 'import sys,json; d=json.load(sys.stdin); r=d.get("result",[]); print(r[0]["id"] if r else "")')"
CURRENT_IP="$(echo "${RESP}" | python3 -c 'import sys,json; d=json.load(sys.stdin); r=d.get("result",[]); print(r[0].get("content","") if r else "")')"

if [[ -z "${RECORD_ID}" ]]; then
  echo "DNS record not found, creating ${CF_RECORD_NAME} -> ${PUBLIC_IP}"
  CREATE_PAYLOAD="$(python3 - <<PY
import json
print(json.dumps({
  "type": "${CF_RECORD_TYPE}",
  "name": "${CF_RECORD_NAME}",
  "content": "${PUBLIC_IP}",
  "ttl": int("${CF_TTL}"),
  "proxied": "${CF_PROXIED}".lower() == "true"
}))
PY
)"
  curl -fsS -X POST "${CF_API}/zones/${CF_ZONE_ID}/dns_records" \
    -H "${AUTH_HEADER}" -H "${JSON_HEADER}" \
    --data "${CREATE_PAYLOAD}" >/dev/null
  echo "Created DNS record"
else
  if [[ "${CURRENT_IP}" != "${PUBLIC_IP}" ]]; then
    echo "Updating DNS record ${CF_RECORD_NAME}: ${CURRENT_IP} -> ${PUBLIC_IP}"
    UPDATE_PAYLOAD="$(python3 - <<PY
import json
print(json.dumps({
  "type": "${CF_RECORD_TYPE}",
  "name": "${CF_RECORD_NAME}",
  "content": "${PUBLIC_IP}",
  "ttl": int("${CF_TTL}"),
  "proxied": "${CF_PROXIED}".lower() == "true"
}))
PY
)"
    curl -fsS -X PUT "${CF_API}/zones/${CF_ZONE_ID}/dns_records/${RECORD_ID}" \
      -H "${AUTH_HEADER}" -H "${JSON_HEADER}" \
      --data "${UPDATE_PAYLOAD}" >/dev/null
    echo "Updated DNS record"
  else
    echo "DNS already up to date"
  fi
fi

cd "${ORCH_WORKDIR}"
exec python3 -m uvicorn "${ORCH_MODULE}" --host "${ORCH_HOST}" --port "${ORCH_PORT}"