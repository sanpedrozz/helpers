from fastapi import APIRouter, Depends, HTTPException, Response, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, EmailStr
from types import SimpleNamespace
from .deps import get_db
from ..models.user import User
from ..security.passwords import verify_password
from ..security.jwt import (
    create_access,
    create_refresh,
    decode_token,
    REFRESH_COOKIE_NAME,
)

router = APIRouter(prefix="/auth", tags=["auth"])


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class LoginOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


COOKIE_KW = dict(httponly=True, secure=True, samesite="lax", path="/")

# simple in-memory user store for cases when a real database is not configured
_fake_users = {
    "user@example.com": SimpleNamespace(id=1, password="secret", is_active=True)
}


@router.post("/login", response_model=LoginOut)
async def login(data: LoginIn, resp: Response, db: AsyncSession = Depends(get_db)):
    user = None
    if db:
        user = await db.scalar(select(User).where(User.email == data.email))
        if not user or not verify_password(data.password, user.password_hash) or not user.is_active:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        uid = str(user.id)
    else:
        user = _fake_users.get(data.email)
        if not user or data.password != user.password or not user.is_active:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        uid = str(user.id)
    access = create_access(uid)
    refresh = create_refresh(uid)
    resp.set_cookie(REFRESH_COOKIE_NAME, refresh, max_age=60 * 60 * 24 * 30, **COOKIE_KW)
    return LoginOut(access_token=access)


@router.post("/refresh", response_model=LoginOut)
async def refresh(resp: Response, req: Request):
    rt = req.cookies.get(REFRESH_COOKIE_NAME)
    if not rt:
        raise HTTPException(status_code=401, detail="No refresh cookie")
    try:
        payload = decode_token(rt)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid refresh")
    if payload.typ != "refresh":
        raise HTTPException(status_code=401, detail="Wrong token type")
    access = create_access(payload.sub)
    new_refresh = create_refresh(payload.sub)
    resp.set_cookie(REFRESH_COOKIE_NAME, new_refresh, max_age=60 * 60 * 24 * 30, **COOKIE_KW)
    return LoginOut(access_token=access)


@router.post("/logout")
async def logout(resp: Response):
    resp.delete_cookie(REFRESH_COOKIE_NAME, path="/")
    return {"ok": True}
