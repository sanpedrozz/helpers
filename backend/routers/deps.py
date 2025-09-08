from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession
from ..security.jwt import decode_token
from ..models.user import User

bearer = HTTPBearer(auto_error=False)


async def get_db() -> AsyncSession:
    """Placeholder dependency returning database session."""
    raise NotImplementedError


async def get_current_user(
    cred: HTTPAuthorizationCredentials = Depends(bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    if not cred:
        raise HTTPException(status_code=401, detail="Not authenticated")
    try:
        payload = decode_token(cred.credentials)
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    if payload.typ != "access":
        raise HTTPException(status_code=401, detail="Access token required")
    user = None
    if db:
        user = await db.get(User, int(payload.sub))
    if not user or not getattr(user, "is_active", False):
        raise HTTPException(status_code=401, detail="User disabled")
    return user
