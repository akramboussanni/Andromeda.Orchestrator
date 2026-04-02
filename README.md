# Andromeda Orchestrator (Host Runtime)

Andromeda.Orchestrator is the game-host service that runs dedicated sessions and exposes a small API used by Andromeda.Core. The Orchestrator/Core connection is "engineered" non-orthodox with DNS hacks to try to keep a near-zero cost when unused.

## API

- GET /health
- POST /boot
- POST /sessions/create
- POST /sessions/{session_id}/stop
- GET /sessions/{session_id}/ports

## Authentication

Set HOST_API_TOKEN to require authentication. Clients can send:

- Authorization: Bearer <token>
- X-Api-Token: <token>

## Environment

- HOST_RUNTIME_MODE=docker|process
- HOST_GAME_EXECUTABLE_PATH (required in process mode)
- HOST_PORT_RANGE_START
- HOST_PORT_RANGE_END
- HOST_MAX_SESSIONS
- HOST_DOCKER_IMAGE (required in docker mode)
- HOST_DOCKER_CONTAINER_PREFIX
- HOST_DOCKER_ENTRYPOINT
- HOST_DOCKER_DATA_ROOT (optional; mount path reused by spawned game containers)
- HOST_API_TOKEN (recommended)

## Docker host image automation

Use the image scaffold in `host-image/` for client-based hosting (game client + MelonLoader + Andromeda patches).

- Build context: `Andromeda.Orchestrator/host-image`
- Session containers use the image ENTRYPOINT by default.
- For persistence and fast restarts, set `HOST_DOCKER_DATA_ROOT` so `/data` is shared across runs.

The repository includes a GitHub Actions workflow that publishes this image to GHCR.

### Required deployment notes

- Keep image and registry private.
- Do not commit game files or Steam credentials.
- Anonymous SteamCMD can fail for some depots; use authenticated Steam credentials when needed.
- Verify game licensing terms before automating distribution.

## Windows Support

The orchestrator can natively run and host sessions on Windows without Docker by using `process` mode. 

A setup script is provided to automatically download SteamCMD, install the game server, and install MelonLoader alongside the Andromeda Mod.

1. Double-click or run `setup_windows.bat` in this directory (Requires Windows 10 Build 17063+ or Windows 11).
2. Edit your `.env` file to set:
   - `HOST_RUNTIME_MODE=process`
   - `HOST_GAME_EXECUTABLE_PATH=data\game\enemy-on-board.exe`

## Local run

```bash
uvicorn main:app --host 0.0.0.0 --port 9000
```

## Startup script requirements

If you use `startup.sh` (Cloudflare DNS update + Orchestrator launch), ensure the host has:

- `bash`
- `curl`
- `python3`

Python package requirements remain:

- `fastapi>=0.115.0`
- `uvicorn[standard]>=0.30.0`

Required environment variables for `startup.sh`:

- `CF_API_TOKEN`
- `CF_ZONE_ID`
- `CF_RECORD_NAME`

Common optional variables:

- `CF_RECORD_TYPE` (default `A`)
- `CF_PROXIED` (default `false`)
- `CF_TTL` (default `120`)
- `ORCH_MODULE` (default `main:app`)
- `ORCH_HOST` (default `0.0.0.0`)
- `ORCH_PORT` (default `9000`)
- `ORCH_WORKDIR` (default `/opt/andromeda-orchestrator`)

## Production notes

- Run behind a reverse proxy and firewall.
- Restrict inbound access to trusted central API IPs.
- Use docker mode for reproducible deployments.
- Keep port ranges dedicated to this service only.
