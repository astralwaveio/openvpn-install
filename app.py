import os
import subprocess
from fastapi import FastAPI, HTTPException, Response
from pydantic import BaseModel
from typing import Optional

OPENVPN_CTL = os.environ.get("OPENVPN_CTL", os.path.join(os.path.dirname(__file__), "openvpn-ctl"))
OVPN_OUTPUT_DIR = os.environ.get("OVPN_OUTPUT_DIR", "")

app = FastAPI(
    title="OpenVPN Client Management API",
    description="API for fully automated OpenVPN client management via openvpn-ctl.",
    version="1.0.0"
)

class UserRequest(BaseModel):
    username: str
    password: Optional[str] = None

class ExportRequest(BaseModel):
    username: str
    output_path: str

@app.post("/add_user")
def add_user(req: UserRequest):
    args = [OPENVPN_CTL, "add", req.username]
    if req.password:
        args += ["--pass", req.password]
    env = os.environ.copy()
    if OVPN_OUTPUT_DIR:
        env["OVPN_OUTPUT_DIR"] = OVPN_OUTPUT_DIR
    try:
        result = subprocess.run(args, capture_output=True, text=True, env=env, timeout=60)
        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=result.stderr or result.stdout)
        # Return the ovpn file content as well
        ovpn_path = os.path.join(OVPN_OUTPUT_DIR, f"{req.username}.ovpn") if OVPN_OUTPUT_DIR else f"{req.username}.ovpn"
        if not os.path.exists(ovpn_path):
            raise HTTPException(status_code=500, detail="Client .ovpn file not found after creation.")
        with open(ovpn_path, "r") as f:
            ovpn_content = f.read()
        return {"username": req.username, "ovpn": ovpn_content}
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=500, detail="Timeout running openvpn-ctl add.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/revoke_user")
def revoke_user(req: UserRequest):
    args = [OPENVPN_CTL, "revoke", req.username]
    env = os.environ.copy()
    if OVPN_OUTPUT_DIR:
        env["OVPN_OUTPUT_DIR"] = OVPN_OUTPUT_DIR
    result = subprocess.run(args, capture_output=True, text=True, env=env, timeout=60)
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=result.stderr or result.stdout)
    return {"username": req.username, "status": "revoked"}

@app.post("/regen_user")
def regen_user(req: UserRequest):
    args = [OPENVPN_CTL, "regen", req.username]
    if req.password:
        args += ["--pass", req.password]
    env = os.environ.copy()
    if OVPN_OUTPUT_DIR:
        env["OVPN_OUTPUT_DIR"] = OVPN_OUTPUT_DIR
    result = subprocess.run(args, capture_output=True, text=True, env=env, timeout=120)
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=result.stderr or result.stdout)
    # Return the ovpn file content as well
    ovpn_path = os.path.join(OVPN_OUTPUT_DIR, f"{req.username}.ovpn") if OVPN_OUTPUT_DIR else f"{req.username}.ovpn"
    if not os.path.exists(ovpn_path):
        raise HTTPException(status_code=500, detail="Client .ovpn file not found after regen.")
    with open(ovpn_path, "r") as f:
        ovpn_content = f.read()
    return {"username": req.username, "ovpn": ovpn_content, "status": "regenerated"}

@app.post("/list_users")
def list_users():
    args = [OPENVPN_CTL, "list"]
    env = os.environ.copy()
    if OVPN_OUTPUT_DIR:
        env["OVPN_OUTPUT_DIR"] = OVPN_OUTPUT_DIR
    result = subprocess.run(args, capture_output=True, text=True, env=env, timeout=30)
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=result.stderr or result.stdout)
    # Parse user list from output
    users = []
    for line in result.stdout.strip().splitlines():
        # Skip header, simple parse
        if line and not line.lower().startswith("name"):
            users.append(line.strip())
    return {"users": users}

@app.post("/show_ovpn")
def show_ovpn(req: UserRequest):
    args = [OPENVPN_CTL, "show", req.username]
    env = os.environ.copy()
    if OVPN_OUTPUT_DIR:
        env["OVPN_OUTPUT_DIR"] = OVPN_OUTPUT_DIR
    result = subprocess.run(args, capture_output=True, text=True, env=env, timeout=30)
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=result.stderr or result.stdout)
    return Response(content=result.stdout, media_type="text/plain")

@app.post("/export_ovpn")
def export_ovpn(req: ExportRequest):
    args = [OPENVPN_CTL, "export", req.username, req.output_path]
    env = os.environ.copy()
    if OVPN_OUTPUT_DIR:
        env["OVPN_OUTPUT_DIR"] = OVPN_OUTPUT_DIR
    result = subprocess.run(args, capture_output=True, text=True, env=env, timeout=30)
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=result.stderr or result.stdout)
    return {"username": req.username, "exported_to": req.output_path}



