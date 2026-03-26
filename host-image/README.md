# Andromeda EOB Host Image

This directory contains a Docker image scaffold for running Enemy On Board sessions through Andromeda.Orchestrator in docker mode.

## What it does

- Installs Wine and SteamCMD into the image.
- On container start, installs or updates app `999860` into a persistent game directory.
- Applies optional MelonLoader and Andromeda.Mod payloads.
- Launches `enemy-on-board.exe` under Wine and forwards runtime args from Orchestrator.

## Why this boot model is fast after first run

- Docker image layers (including Wine) are cached on the host VM.
- Steam and game files live on mounted persistent storage (`/data/...`).
- Restarts only relaunch the game process unless an update is required.

## Build locally

```bash
docker build -f Andromeda.Orchestrator/host-image/Dockerfile -t andromeda-eob-host:local Andromeda.Orchestrator/host-image
```

## Expected runtime env

Use the variables in `.env.example` as your baseline.

Important:

- `STEAM_USER=anonymous` may fail depending on Steam depot access for app `999860`.
- If anonymous fails, set `STEAM_USER` and `STEAM_PASS` via runtime secrets.

## Integrate with Orchestrator

Set in `Andromeda.Orchestrator/.env.example` or your deployment env:

- `HOST_RUNTIME_MODE=docker`
- `HOST_DOCKER_IMAGE=ghcr.io/<owner>/andromeda-eob-host:<tag>`
- `HOST_DOCKER_ENTRYPOINT=` (empty to use image ENTRYPOINT)

## Persistent volumes

When running the session containers, mount a persistent host path to `/data` so Steam and Wine state is reused.

## Security and licensing

- Do not commit game files or Steam credentials.
- Keep the built image and registry private.
- Verify the game EULA before automating redistribution or multi-user hosting.
