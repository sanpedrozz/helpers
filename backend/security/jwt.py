from datetime import datetime, timedelta, timezone
from jose import jwt
from pydantic import BaseModel
from types import SimpleNamespace

# In a real application this would come from configuration
settings = SimpleNamespace(JWT_SECRET="change-me")

JWT_SECRET = settings.JWT_SECRET
JWT_ALG = "HS256"
ACCESS_TTL_MIN = 15
REFRESH_TTL_DAYS = 30
REFRESH_COOKIE_NAME = "rt"


class TokenPayload(BaseModel):
    sub: str
    typ: str  # "access" | "refresh"
    exp: int


def create_access(sub: str) -> str:
    exp = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TTL_MIN)
    return jwt.encode({"sub": sub, "typ": "access", "exp": int(exp.timestamp())},
                      JWT_SECRET, algorithm=JWT_ALG)


def create_refresh(sub: str) -> str:
    exp = datetime.now(timezone.utc) + timedelta(days=REFRESH_TTL_DAYS)
    return jwt.encode({"sub": sub, "typ": "refresh", "exp": int(exp.timestamp())},
                      JWT_SECRET, algorithm=JWT_ALG)


def decode_token(token: str) -> TokenPayload:
    return TokenPayload(**jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG]))
