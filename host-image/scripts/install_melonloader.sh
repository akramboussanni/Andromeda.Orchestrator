#!/usr/bin/env bash
set -euo pipefail

GAME_DIR="${GAME_DIR:-/data/game}"
MELONLOADER_DIR="${MELONLOADER_DIR:-/data/melonloader}"
MELONLOADER_URL="${MELONLOADER_URL:-}"
MELONLOADER_VERSION="${MELONLOADER_VERSION:-manual}"
STAMP_FILE="${MELONLOADER_DIR}/.melonloader_version"

mkdir -p "${MELONLOADER_DIR}"

if [[ -f "${STAMP_FILE}" ]] && [[ "$(cat "${STAMP_FILE}")" == "${MELONLOADER_VERSION}" ]]; then
  echo "[bootstrap] MelonLoader already at version ${MELONLOADER_VERSION}"
  exit 0
fi

if [[ -z "${MELONLOADER_URL}" ]]; then
  echo "[bootstrap] MELONLOADER_URL not set; skipping automated MelonLoader install"
  echo "manual" > "${STAMP_FILE}"
  exit 0
fi

tmp_zip="$(mktemp)"
echo "[bootstrap] Downloading MelonLoader from ${MELONLOADER_URL}"
curl -fsSL "${MELONLOADER_URL}" -o "${tmp_zip}"

# MelonLoader package structure can vary by release. Unzip into game root.
unzip -o "${tmp_zip}" -d "${GAME_DIR}" >/dev/null
rm -f "${tmp_zip}"

echo "${MELONLOADER_VERSION}" > "${STAMP_FILE}"
echo "[bootstrap] MelonLoader install complete"
