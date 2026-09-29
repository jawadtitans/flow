import logging
import os
import re
import time
import uuid
from contextlib import asynccontextmanager

import sentry_sdk
from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_client import CollectorRegistry, multiprocess
from prometheus_fastapi_instrumentator import Instrumentator
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import models  # noqa: F401
from app.core.config import get_settings
from app.core.database import engine, get_db
from app.core.health import dependencies
from app.core.logging import configure_logging, request_id_context
from app.modules.admin.router import router as admin_router
from app.modules.auth.router import router as auth_router
from app.modules.categories.router import router as categories_router
from app.modules.notifications.router import router as notifications_router
from app.modules.reminders.router import router as reminders_router
from app.modules.routines.router import router as routines_router
from app.modules.tasks.router import router as tasks_router
from app.modules.users.router import router as users_router
from app.shared.rate_limit import limit

configure_logging()
logger = logging.getLogger(__name__)


def scrub_sentry(event, hint):
    request = event.get("request", {})
    request.pop("data", None)
    request.pop("cookies", None)
    request.pop("query_string", None)
    request.pop("headers", None)
    event.pop("user", None)
    return event


@asynccontextmanager
async def lifespan(app):
    settings = get_settings()
    for name, url in [
        ("redis", settings.redis_url),
        ("limiter", settings.rate_limit_redis_url),
        ("broker", settings.celery_broker_url),
        ("results", settings.celery_result_backend),
    ]:
        setattr(
            app.state,
            name,
            Redis.from_url(url, decode_responses=True, socket_timeout=2, socket_connect_timeout=2),
        )
    if settings.sentry_dsn:
        sentry_sdk.init(
            dsn=settings.sentry_dsn,
            environment=settings.app_env,
            release=settings.release,
            send_default_pii=False,
            before_send=scrub_sentry,
            traces_sample_rate=0.0,
        )
    yield
    for name in ("redis", "limiter", "broker", "results"):
        await getattr(app.state, name).aclose()
    await engine.dispose()


def create_app():
    app = FastAPI(
        title="Flow API", version="0.2.0", openapi_url="/api/v1/openapi.json", lifespan=lifespan
    )
    settings = get_settings()
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=[
            "Authorization",
            "Content-Type",
            "X-Flow-CSRF",
            "X-Request-ID",
            "Idempotency-Key",
        ],
        expose_headers=["X-Request-ID", "Retry-After"],
    )

    @app.middleware("http")
    async def request_context(request: Request, call_next):
        supplied = request.headers.get("X-Request-ID", "")
        rid = supplied if re.fullmatch(r"[a-zA-Z0-9._-]{1,64}", supplied) else str(uuid.uuid4())
        request.state.request_id = rid
        token = request_id_context.set(rid)
        started = time.monotonic()
        try:
            if request.url.path.startswith("/api/v1/") and not request.url.path.startswith(
                ("/api/v1/auth/", "/api/v1/admin/")
            ):
                try:
                    await limit(
                        request,
                        "public",
                        request.client.host if request.client else "unknown",
                        settings.public_rate_limit,
                    )
                except HTTPException as exc:
                    response = JSONResponse(
                        {"detail": exc.detail}, status_code=exc.status_code, headers=exc.headers
                    )
                else:
                    response = await call_next(request)
            else:
                response = await call_next(request)
            response.headers["X-Request-ID"] = rid
            response.headers["X-Content-Type-Options"] = "nosniff"
            response.headers["Referrer-Policy"] = "no-referrer"
            if request.url.path.startswith("/api/v1/"):
                response.headers["Cache-Control"] = "no-store"
            logger.info(
                "request",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "status": response.status_code,
                    "duration_ms": round((time.monotonic() - started) * 1000, 2),
                    "user_id": getattr(request.state, "user_id", None),
                },
            )
            return response
        finally:
            request_id_context.reset(token)

    for router in (
        auth_router,
        users_router,
        tasks_router,
        categories_router,
        routines_router,
        reminders_router,
        notifications_router,
        admin_router,
    ):
        app.include_router(router, prefix="/api/v1")

    @app.get("/health", tags=["operations"])
    async def health():
        return {"status": "ok"}

    @app.get("/ready", tags=["operations"])
    async def ready(request: Request, db: AsyncSession = Depends(get_db)):
        state = await dependencies(db, request.app)
        ok = all(value == "ok" for value in state.values())
        return JSONResponse({"status": "ok" if ok else "error"}, status_code=200 if ok else 503)

    registry = CollectorRegistry()
    if os.environ.get("PROMETHEUS_MULTIPROC_DIR"):
        multiprocess.MultiProcessCollector(registry)
    Instrumentator(
        registry=registry,
        excluded_handlers=["/health", "/ready", "/metrics"],
        should_group_status_codes=True,
    ).instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)
    return app


app = create_app()
