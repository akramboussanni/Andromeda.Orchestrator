#!/usr/bin/env bash
set -euo pipefail

STEAMCMD_DIR="${STEAMCMD_DIR:-/opt/steamcmd}"
STEAMCMD_URL="${STEAMCMD_URL:-https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz}"

mkdir -p "${STEAMCMD_DIR}"

if [[ ! -x "${STEAMCMD_DIR}/steamcmd.sh" ]]; then
  echo "[bootstrap] Installing SteamCMD into ${STEAMCMD_DIR}"
  tmp_tar="$(mktemp)"
  curl -fsSL "${STEAMCMD_URL}" -o "${tmp_tar}"
  tar -xzf "${tmp_tar}" -C "${STEAMCMD_DIR}"
  rm -f "${tmp_tar}"
  
  # Fix permissions on steamcmd binary
  if [[ -f "${STEAMCMD_DIR}/steamcmd.sh" ]]; then
    chmod +x "${STEAMCMD_DIR}/steamcmd.sh"
  fi
  if [[ -f "${STEAMCMD_DIR}/linux32/steamcmd" ]]; then
    chmod +x "${STEAMCMD_DIR}/linux32/steamcmd"
  fi
else
  echo "[bootstrap] SteamCMD already installed"
fi
