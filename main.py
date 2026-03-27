import os
from typing import Any, Optional

import runtime
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

load_dotenv()
app = FastAPI(title="Andromeda Host Runtime", version="1.0.0")
API_TOKEN = os.getenv("HOST_API_TOKEN", "").strip()


class SessionCreateRequest(BaseModel):
    region: str
    name: str
    sessionId: str
    isPublic: bool = False
    gamemode: str = "CustomParty"
    gamemodeData: Any = None


class SessionStopRequest(BaseModel):
    reason: Optional[str] = None


def _check_auth(authorization: Optional[str], x_api_token: Optional[str]) -> None:
    if not API_TOKEN:
        return
    bearer = (authorization or "").removeprefix("Bearer ").strip()
    provided = x_api_token or bearer
    if provided != API_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")


@app.get("/health")
def health():
    return {"status": "ok", **runtime.stats()}


@app.post("/boot")
def boot(
    authorization: Optional[str] = Header(None),
    x_api_token: Optional[str] = Header(None, alias="X-Api-Token"),
):
    _check_auth(authorization, x_api_token)
    return {"status": "ok", "message": "host runtime reachable"}


@app.post("/sessions/create")
def sessions_create(
    body: SessionCreateRequest,
    authorization: Optional[str] = Header(None),
    x_api_token: Optional[str] = Header(None, alias="X-Api-Token"),
):
    _check_auth(authorization, x_api_token)
    try:
        return runtime.create_session(body.model_dump())
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))


@app.post("/sessions/{session_id}/stop")
def sessions_stop(
    session_id: str,
    body: SessionStopRequest,
    authorization: Optional[str] = Header(None),
    x_api_token: Optional[str] = Header(None, alias="X-Api-Token"),
):
    _check_auth(authorization, x_api_token)
    runtime.stop_session(session_id, reason=body.reason or "manual")
    return {"status": "ok"}


@app.get("/sessions/{session_id}/ports")
def sessions_ports(
    session_id: str,
    authorization: Optional[str] = Header(None),
    x_api_token: Optional[str] = Header(None, alias="X-Api-Token"),
):
    _check_auth(authorization, x_api_token)
    ports = runtime.get_ports(session_id)
    if not ports:
        raise HTTPException(status_code=404, detail="Session not found")
    return ports
