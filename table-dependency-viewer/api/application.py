"""FastAPI application factory.

Keeping infrastructure setup here lets domain routers move out of ``main.py``
incrementally without changing the public ASGI entry point.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import CORS_ORIGINS


def create_application() -> FastAPI:
    app = FastAPI(title="DWH Control API")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    return app
