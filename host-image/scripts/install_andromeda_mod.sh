#!/usr/bin/env bash
set -euo pipefail

GAME_DIR="${GAME_DIR:-/data/game}"
MODS_DIR="${MODS_DIR:-/data/mods}"
ANDROMEDA_MOD_URL="${ANDROMEDA_MOD_URL:-}"
ANDROMEDA_MOD_VERSION="${ANDROMEDA_MOD_VERSION:-manual}"
MODS_TARGET_DIR="${GAME_DIR}/Mods"
STAMP_FILE="${MODS_DIR}/.andromeda_mod_version"

mkdir -p "${MODS_DIR}" "${MODS_TARGET_DIR}"

if [[ -f "${STAMP_FILE}" ]] && [[ "$(cat "${STAMP_FILE}")" == "${ANDROMEDA_MOD_VERSION}" ]]; then
  echo "[bootstrap] Andromeda mod already at version ${ANDROMEDA_MOD_VERSION}"
  exit 0
fi

if [[ -n "${ANDROMEDA_MOD_URL}" ]]; then
  tmp_mod="$(mktemp)"
  echo "[bootstrap] Downloading Andromeda mod payload"
  curl -fsSL "${ANDROMEDA_MOD_URL}" -o "${tmp_mod}"

  # Supports a zip payload or direct DLL payload.
  if unzip -tqq "${tmp_mod}" >/dev/null 2>&1; then
    unzip -o "${tmp_mod}" -d "${MODS_TARGET_DIR}" >/dev/null
  else
    cp -f "${tmp_mod}" "${MODS_TARGET_DIR}/Andromeda.Mod.dll"
  fi
  rm -f "${tmp_mod}"
else
  # Fallback: if a mod artifact is bind-mounted into /data/mods, copy it.
  if [[ -f "${MODS_DIR}/Andromeda.Mod.dll" ]]; then
    cp -f "${MODS_DIR}/Andromeda.Mod.dll" "${MODS_TARGET_DIR}/Andromeda.Mod.dll"
  fi
fi

echo "${ANDROMEDA_MOD_VERSION}" > "${STAMP_FILE}"
echo "[bootstrap] Andromeda mod install complete"
