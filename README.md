# Andromeda Host Runtime

Host Runtime is the game-host service that runs dedicated sessions and exposes a small API used by PythonServer.

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
- HOST_API_TOKEN (recommended)

## Local run

```bash
uvicorn main:app --host 0.0.0.0 --port 9000
```

## Production notes

- Run behind a reverse proxy and firewall.
- Restrict inbound access to trusted central API IPs.
- Use docker mode for reproducible deployments.
- Keep port ranges dedicated to this service only.
