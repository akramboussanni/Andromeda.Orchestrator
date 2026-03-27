import base64
import json
import logging
import os
import pathlib
import shlex
import socket
import subprocess
import threading
import time
from typing import Any

logger = logging.getLogger("HostRuntime")

RUNTIME_MODE = os.getenv("HOST_RUNTIME_MODE", "docker").strip().lower()
GAME_EXE = os.getenv("HOST_GAME_EXECUTABLE_PATH", "/opt/eob/enemy-on-board.exe")
PORT_RANGE_START = int(os.getenv("HOST_PORT_RANGE_START", "7777"))
PORT_RANGE_END = int(os.getenv("HOST_PORT_RANGE_END", "7977"))
MAX_SESSIONS = int(os.getenv("HOST_MAX_SESSIONS", "6"))
DOCKER_IMAGE = os.getenv("HOST_DOCKER_IMAGE", "").strip()
DOCKER_CONTAINER_PREFIX = os.getenv("HOST_DOCKER_CONTAINER_PREFIX", "andromeda-eob")
DOCKER_AUTO_REMOVE = os.getenv("HOST_DOCKER_AUTO_REMOVE", "false").strip().lower() == "true"
DOCKER_ENTRYPOINT = os.getenv("HOST_DOCKER_ENTRYPOINT", "")
DOCKER_DATA_ROOT = os.getenv("HOST_DOCKER_DATA_ROOT", "").strip()
STEAM_CACHE_VOLUME = os.getenv("HOST_STEAM_CACHE_VOLUME", "").strip()
MELONLOADER_URL = os.getenv("MELONLOADER_URL", "https://api.github.com/repos/LavaGang/MelonLoader/releases/latest")
MELONLOADER_VERSION = os.getenv("MELONLOADER_VERSION", "")
ANDROMEDA_MOD_URL = os.getenv("ANDROMEDA_MOD_URL", "https://api.github.com/repos/akramboussanni/Andromeda.Mod/releases/latest")
ANDROMEDA_MOD_VERSION = os.getenv("ANDROMEDA_MOD_VERSION", "")

logger.info("[STARTUP] Configuration loaded:")
logger.info("[STARTUP]   RUNTIME_MODE=%s", RUNTIME_MODE)
logger.info("[STARTUP]   DOCKER_IMAGE=%s", DOCKER_IMAGE)
logger.info("[STARTUP]   DOCKER_CONTAINER_PREFIX=%s", DOCKER_CONTAINER_PREFIX)
logger.info("[STARTUP]   DOCKER_ENTRYPOINT=%s", DOCKER_ENTRYPOINT)
logger.info("[STARTUP]   DOCKER_DATA_ROOT=%s", DOCKER_DATA_ROOT)
logger.info("[STARTUP]   STEAM_CACHE_VOLUME=%s", STEAM_CACHE_VOLUME)
logger.info("[STARTUP]   MELONLOADER_URL=%s", MELONLOADER_URL)
logger.info("[STARTUP]   ANDROMEDA_MOD_URL=%s", ANDROMEDA_MOD_URL)
logger.info("[STARTUP]   PORT_RANGE=%s-%s", PORT_RANGE_START, PORT_RANGE_END)
logger.info("[STARTUP]   MAX_SESSIONS=%s", MAX_SESSIONS)

_FORWARDED_CONTAINER_ENV = (
    "STEAM_USER",
    "STEAM_PASS",
    "STEAM_AUTH_CODE",
    "STEAM_GUARD_CODE",
    "STEAM_BRANCH",
    "STEAM_BRANCH_PASSWORD",
    "EOB_APP_ID",
    "EOB_AUTO_UPDATE",
    "EOB_VALIDATE",
    "EOB_EXE_RELATIVE_PATH",
    "MELONLOADER_URL",
    "MELONLOADER_VERSION",
    "ANDROMEDA_MOD_URL",
    "ANDROMEDA_MOD_VERSION",
)

_lock = threading.Lock()
_used_ports: set[int] = set()
_sessions: dict[str, dict[str, Any]] = {}


def _is_port_available(port: int) -> bool:
    tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        tcp.bind(("0.0.0.0", port))
        udp.bind(("0.0.0.0", port))
        return True
    except OSError:
        return False
    finally:
        tcp.close()
        udp.close()


def _allocate_pair(session_id: str) -> tuple[int, int]:
    with _lock:
        if session_id in _sessions:
            s = _sessions[session_id]
            return int(s["gamePort"]), int(s["voicePort"])

        if len(_sessions) >= MAX_SESSIONS:
            raise RuntimeError(f"max sessions reached ({MAX_SESSIONS})")

        start = PORT_RANGE_START if PORT_RANGE_START % 2 == 1 else PORT_RANGE_START + 1
        for game_port in range(start, PORT_RANGE_END + 1, 2):
            voice_port = game_port + 1
            if voice_port > PORT_RANGE_END:
                break
            if game_port in _used_ports or voice_port in _used_ports:
                continue
            if not _is_port_available(game_port) or not _is_port_available(voice_port):
                continue
            _used_ports.add(game_port)
            _used_ports.add(voice_port)
            return game_port, voice_port

    raise RuntimeError("no free game/voice port pair")


def _release_pair(session_id: str):
    with _lock:
        state = _sessions.get(session_id)
        if not state:
            return
        _used_ports.discard(int(state["gamePort"]))
        _used_ports.discard(int(state["voicePort"]))


def _build_container_env_args(session_id: str) -> list[str]:
    args = ["-e", f"ANDROMEDA_SESSION_ID={session_id}"]
    if DOCKER_DATA_ROOT:
        args.extend(["-e", "GAME_DIR=/data/game"])
        args.extend(["-e", f"WINEPREFIX=/data/wineprefix/{session_id}"])
        args.extend(["-e", "MELONLOADER_DIR=/data/melonloader"])
        args.extend(["-e", "MODS_DIR=/data/mods"])

    # Forward Steam vars
    for env_name in ("STEAM_USER", "STEAM_PASS", "STEAM_AUTH_CODE", "STEAM_GUARD_CODE", "STEAM_BRANCH", "STEAM_BRANCH_PASSWORD", "EOB_APP_ID", "EOB_AUTO_UPDATE", "EOB_VALIDATE", "EOB_EXE_RELATIVE_PATH"):
        value = os.getenv(env_name)
        if value is not None and value != "":
            args.extend(["-e", f"{env_name}={value}"])
    
    # Pass MelonLoader & Andromeda with defaults
    args.extend(["-e", f"MELONLOADER_URL={MELONLOADER_URL}"])
    if MELONLOADER_VERSION:
        args.extend(["-e", f"MELONLOADER_VERSION={MELONLOADER_VERSION}"])
    args.extend(["-e", f"ANDROMEDA_MOD_URL={ANDROMEDA_MOD_URL}"])
    if ANDROMEDA_MOD_VERSION:
        args.extend(["-e", f"ANDROMEDA_MOD_VERSION={ANDROMEDA_MOD_VERSION}"])
    
    return args


def _build_container_volume_args() -> list[str]:
    args = []
    if DOCKER_DATA_ROOT:
        host_path = pathlib.Path(DOCKER_DATA_ROOT).expanduser().resolve()
        host_path.mkdir(parents=True, exist_ok=True)
        args.extend(["-v", f"{host_path}:/data"])
    if STEAM_CACHE_VOLUME:
        # STEAM_CACHE_VOLUME can be a named Docker volume or a host path
        # Examples: "steam-login-cache" or "/mnt/steam-cache"
        args.extend(["-v", f"{STEAM_CACHE_VOLUME}:/home/andromeda/.steam"])
    return args


def create_session(payload: dict[str, Any]) -> dict[str, Any]:
    session_id = str(payload.get("sessionId", "")).strip()
    if not session_id:
        raise RuntimeError("sessionId is required")

    logger.info("[DEBUG] create_session called with: sessionId=%s, payload keys=%s", session_id, list(payload.keys()))

    region = str(payload.get("region", "us"))
    name = str(payload.get("name", "Andromeda Session"))
    gamemode = str(payload.get("gamemode", "CustomParty"))
    gamemode_data = payload.get("gamemodeData")
    is_public = bool(payload.get("isPublic", False))

    logger.info("[DEBUG] session config: region=%s, name=%s, gamemode=%s, isPublic=%s", region, name, gamemode, is_public)

    game_port, voice_port = _allocate_pair(session_id)
    logger.info("[DEBUG] allocated ports: gamePort=%s, voicePort=%s", game_port, voice_port)

    if RUNTIME_MODE not in ("docker", "process"):
        raise RuntimeError(f"unsupported HOST_RUNTIME_MODE={RUNTIME_MODE}")

    logger.info("[DEBUG] RUNTIME_MODE=%s", RUNTIME_MODE)

    args = [
        "-batchmode",
        "-nographics",
        "--server",
        "--port", str(game_port),
        "--region", region,
        "--session-id", session_id,
        "--name", name,
        "--mode", gamemode,
    ]

    if gamemode_data is not None:
        mode_json = json.dumps(gamemode_data, separators=(",", ":"))
        mode_b64 = base64.b64encode(mode_json.encode("utf-8")).decode("ascii")
        args.extend(["--mode-data-b64", mode_b64])

    if is_public:
        args.append("--public")

    try:
        if RUNTIME_MODE == "docker":
            if not DOCKER_IMAGE:
                logger.error("[DEBUG] DOCKER_IMAGE is empty! DOCKER_IMAGE='%s'", DOCKER_IMAGE)
                raise RuntimeError("HOST_DOCKER_IMAGE is required for docker mode")

            logger.info("[DEBUG] docker mode: DOCKER_IMAGE=%s", DOCKER_IMAGE)

            cname = f"{DOCKER_CONTAINER_PREFIX}-{session_id[:12]}"
            logger.info("[DEBUG] container name will be: %s", cname)

            cmd = ["docker", "run", "-d", "--security-opt", "seccomp=unconfined"]
            if DOCKER_AUTO_REMOVE:
                cmd.append("--rm")
            cmd.extend([
                "--name", cname,
            ])
            cmd.extend(_build_container_volume_args())
            cmd.extend(_build_container_env_args(session_id))
            cmd.extend([
                "-p", f"{game_port}:{game_port}/udp",
                "-p", f"{game_port}:{game_port}/tcp",
                "-p", f"{voice_port}:{voice_port}/udp",
                DOCKER_IMAGE,
            ])
            if DOCKER_ENTRYPOINT:
                logger.info("[DEBUG] adding DOCKER_ENTRYPOINT: %s", DOCKER_ENTRYPOINT)
                cmd.extend(shlex.split(DOCKER_ENTRYPOINT))
            cmd.extend(args)

            logger.info("[DEBUG] full docker command: %s", " ".join(cmd))
            logger.info("starting docker session=%s gamePort=%s voicePort=%s", session_id, game_port, voice_port)
            
            try:
                cid = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True).strip()
                logger.info("[DEBUG] docker container started successfully: containerID=%s", cid)
            except subprocess.CalledProcessError as e:
                logger.error("[DEBUG] docker run failed with exit code %s: %s", e.returncode, e.output)
                raise RuntimeError(f"docker run failed: {e.output}")
            
            with _lock:
                _sessions[session_id] = {
                    "runtime": "docker",
                    "container": cname,
                    "containerId": cid,
                    "gamePort": game_port,
                    "voicePort": voice_port,
                    "createdAt": time.time(),
                }
        else:
            logger.info("[DEBUG] process mode: GAME_EXE=%s", GAME_EXE)
            if not os.path.exists(GAME_EXE):
                logger.error("[DEBUG] game executable missing: %s", GAME_EXE)
                raise RuntimeError(f"game executable missing: {GAME_EXE}")

            logger.info("starting process session=%s gamePort=%s voicePort=%s", session_id, game_port, voice_port)
            proc = subprocess.Popen([GAME_EXE] + args)
            with _lock:
                _sessions[session_id] = {
                    "runtime": "process",
                    "pid": proc.pid,
                    "proc": proc,
                    "gamePort": game_port,
                    "voicePort": voice_port,
                    "createdAt": time.time(),
                }

        return {
            "sessionId": session_id,
            "gamePort": game_port,
            "voicePort": voice_port,
        }
    except Exception:
        logger.exception("failed to create session=%s", session_id)
        _release_pair(session_id)
        with _lock:
            _sessions.pop(session_id, None)
        raise


def stop_session(session_id: str, reason: str = "manual") -> bool:
    with _lock:
        state = _sessions.get(session_id)

    if not state:
        return False

    try:
        if state.get("runtime") == "docker":
            container = state.get("container")
            if container:
                subprocess.call(["docker", "stop", str(container)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            proc = state.get("proc")
            if proc is not None and proc.poll() is None:
                proc.terminate()
    finally:
        with _lock:
            _sessions.pop(session_id, None)
            _used_ports.discard(int(state["gamePort"]))
            _used_ports.discard(int(state["voicePort"]))

    logger.info("stopped session=%s reason=%s", session_id, reason)
    return True


def get_ports(session_id: str) -> dict[str, int] | None:
    with _lock:
        s = _sessions.get(session_id)
        if not s:
            return None
        return {"gamePort": int(s["gamePort"]), "voicePort": int(s["voicePort"])}


def stats() -> dict[str, Any]:
    with _lock:
        return {
            "runtime": RUNTIME_MODE,
            "activeSessions": len(_sessions),
            "maxSessions": MAX_SESSIONS,
            "portRange": [PORT_RANGE_START, PORT_RANGE_END],
        }
