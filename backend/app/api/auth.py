"""
Supabase JWT authentication dependency for FastAPI.

Every protected endpoint declares:
    user_id: str = Depends(require_auth)

The dependency verifies the Bearer token supplied by the mobile app
(supabase_flutter automatically attaches it on every authenticated request)
and returns the authenticated user's UUID.

Public endpoints (health, predictions) do NOT use this dependency.
"""
from __future__ import annotations

import os
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

_bearer = HTTPBearer(auto_error=True)

# The Supabase JWT secret is the project's JWT secret, available in
# Supabase dashboard → Settings → API → JWT Settings → JWT Secret.
# Set SUPABASE_JWT_SECRET in the Render environment. Never commit it.
_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", "")
_SUPABASE_URL = os.getenv("SUPABASE_URL", "")


def _verify_supabase_token(token: str) -> str:
    """
    Verify a Supabase-issued JWT and return the subject (user UUID).

    Raises HTTP 401 on any verification failure.
    """
    if not _JWT_SECRET:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="SUPABASE_JWT_SECRET is not configured on the server.",
        )
    try:
        payload = jwt.decode(
            token,
            _JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
        user_id: str | None = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token payload missing subject (user id).",
            )
        return user_id
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired. Re-authenticate and retry.",
        )
    except jwt.InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {exc}",
        )


def require_auth(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(_bearer)],
) -> str:
    """FastAPI dependency — verifies Bearer JWT, returns verified user UUID."""
    return _verify_supabase_token(credentials.credentials)
