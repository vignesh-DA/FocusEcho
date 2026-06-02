from __future__ import annotations

from contextlib import asynccontextmanager
from os import getenv

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from .api.routes.analytics import router as analytics_router
from .api.routes.events import router as events_router
from .api.routes.health import router as health_router
from .api.routes.scoring import router as scoring_router
from .api.routes.sessions import router as sessions_router


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield


app = FastAPI(title="Focus Echo AI API", version="1.0.0", lifespan=lifespan)
origins = [origin.strip() for origin in getenv("ALLOWED_ORIGINS", "http://localhost:3000").split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(sessions_router)
app.include_router(events_router)
app.include_router(analytics_router)
app.include_router(scoring_router)
app.include_router(health_router)


@app.get("/", include_in_schema=False)
def root() -> RedirectResponse:
    return RedirectResponse(url="/docs")


@app.get("/health")
def root_health() -> dict[str, str]:
    return {"status": "ok", "version": "1.0.0"}
