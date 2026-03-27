#!/usr/bin/env bash
set -euo pipefail

STEAMCMD_DIR="${STEAMCMD_DIR:-/opt/steamcmd}"
GAME_DIR="${GAME_DIR:-/data/game}"
WINEPREFIX="${WINEPREFIX:-/data/wineprefix}"
EOB_APP_ID="${EOB_APP_ID:-999860}"
EOB_EXE_RELATIVE_PATH="${EOB_EXE_RELATIVE_PATH:-enemy-on-board.exe}"
EOB_VALIDATE="${EOB_VALIDATE:-0}"
EOB_AUTO_UPDATE="${EOB_AUTO_UPDATE:-1}"

STEAM_USER="${STEAM_USER:-anonymous}"
STEAM_PASS="${STEAM_PASS:-}"
STEAM_AUTH_CODE="${STEAM_AUTH_CODE:-}"
STEAM_GUARD_CODE="${STEAM_GUARD_CODE:-}"
STEAM_BRANCH="${STEAM_BRANCH:-}"
STEAM_BRANCH_PASSWORD="${STEAM_BRANCH_PASSWORD:-}"
STEAM_USE_CACHE="${STEAM_USE_CACHE:-1}"

# Set environment variables to help prevent segfaults and improve stability
export MALLOC_TRIM_THRESHOLD=128000
export LD_LIBRARY_PATH="/lib/i386-linux-gnu:/usr/lib/i386-linux-gnu:${LD_LIBRARY_PATH:-}"

mkdir -p "${GAME_DIR}" "${WINEPREFIX}"

/opt/andromeda/install_steamcmd.sh

run_steamcmd_install() {
  local app_update_args=("+app_update" "${EOB_APP_ID}")
  if [[ "${EOB_VALIDATE}" == "1" ]]; then
    app_update_args+=("validate")
  fi

  local branch_args=()
  if [[ -n "${STEAM_BRANCH}" ]]; then
    branch_args+=("-beta" "${STEAM_BRANCH}")
  fi
  if [[ -n "${STEAM_BRANCH_PASSWORD}" ]]; then
    branch_args+=("-betapassword" "${STEAM_BRANCH_PASSWORD}")
  fi

  local auth="${STEAM_AUTH_CODE:-${STEAM_GUARD_CODE:-}}"

  if [[ "${STEAM_USER}" == "anonymous" ]]; then
    echo "[bootstrap] Running SteamCMD with anonymous login"
    "${STEAMCMD_DIR}/steamcmd.sh" \
      +force_install_dir "${GAME_DIR}" \
      +login anonymous \
      "${app_update_args[@]}" \
      "${branch_args[@]}" \
      +quit
  else
    echo "[bootstrap] Running SteamCMD with authenticated login for ${STEAM_USER}"
    local login_args=("+login" "${STEAM_USER}")
    
    # If using cached login token (empty password), don't pass password
    # Steam will use cached credentials from ~/.steam directory
    if [[ -n "${STEAM_PASS}" ]]; then
      login_args+=("${STEAM_PASS}")
      if [[ -n "${auth}" ]]; then
        login_args+=("${auth}")
      fi
      echo "[bootstrap] Using provided credentials (first-time setup)"
    else
      echo "[bootstrap] Using cached login token from ~/.steam directory"
    fi
    
    "${STEAMCMD_DIR}/steamcmd.sh" \
      +force_install_dir "${GAME_DIR}" \
      "${login_args[@]}" \
      "${app_update_args[@]}" \
      "${branch_args[@]}" \
      +quit
  fi
}

if [[ "${EOB_AUTO_UPDATE}" == "1" ]] || [[ ! -f "${GAME_DIR}/${EOB_EXE_RELATIVE_PATH}" ]]; then
  run_steamcmd_install
else
  echo "[bootstrap] EOB_AUTO_UPDATE=0 and executable exists; skipping SteamCMD update"
fi

/opt/andromeda/install_melonloader.sh
/opt/andromeda/install_andromeda_mod.sh

cd "${GAME_DIR}"

if [[ ! -f "${EOB_EXE_RELATIVE_PATH}" ]]; then
  echo "[bootstrap] Game executable not found at ${GAME_DIR}/${EOB_EXE_RELATIVE_PATH}" >&2
  exit 1
fi

echo "[bootstrap] Launching ${EOB_EXE_RELATIVE_PATH} $*"
exec xvfb-run -a wine "${EOB_EXE_RELATIVE_PATH}" "$@"
