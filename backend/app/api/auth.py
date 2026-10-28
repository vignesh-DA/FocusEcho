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

_bearer = HTTPBearer(auto_error=False)

# The Supabase JWT secret is the project's JWT secret, available in
# Supabase dashboard → Settings → API → JWT Settings → JWT Secret.
# Set SUPABASE_JWT_SECRET in the Render environment. Never commit it.
_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", "")
_SUPABASE_URL = os.getenv("SUPABASE_URL", "")

_jwks_client: jwt.PyJWKClient | None = None


def _get_jwks_client() -> jwt.PyJWKClient | None:
    global _jwks_client
    if _jwks_client is None and _SUPABASE_URL:
        jwks_url = f"{_SUPABASE_URL.rstrip('/')}/auth/v1/.well-known/jwks.json"
        _jwks_client = jwt.PyJWKClient(jwks_url, cache_jwk_set=True, lifespan=3600)
    return _jwks_client


def _verify_supabase_token(token: str) -> str:
    """
    Verify a Supabase-issued JWT and return the subject (user UUID).

    Supports both ES256 (via Supabase JWKS) and HS256 (via SUPABASE_JWT_SECRET).
    Raises HTTP 401 on any verification failure.
    """
    try:
        header = jwt.get_unverified_header(token)
        alg = header.get("alg", "HS256")
        if alg == "ES256":
            jwks = _get_jwks_client()
            if not jwks:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="SUPABASE_URL is not configured on the server for ES256 verification.",
                )
            key = jwks.get_signing_key_from_jwt(token).key
        else:
            if not _JWT_SECRET:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="SUPABASE_JWT_SECRET is not configured on the server.",
                )
            key = _JWT_SECRET

        payload = jwt.decode(
            token,
            key,
            algorithms=["HS256", "ES256"],
            audience="authenticated",
            leeway=120,
        )
        user_id: str | None = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token payload missing subject (user id).",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return user_id
    except HTTPException:
        raise
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired. Re-authenticate and retry.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {exc}",
            headers={"WWW-Authenticate": "Bearer"},
        )


def require_auth(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> str:
    """FastAPI dependency — verifies Bearer JWT, returns verified user UUID."""
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return _verify_supabase_token(credentials.credentials)
