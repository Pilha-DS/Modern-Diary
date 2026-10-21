from datetime import datetime, timezone
from typing import Any

from fastapi import Request
from fastapi.responses import JSONResponse


def utc_timestamp() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def request_id_of(request: Request) -> str:
    return getattr(request.state, "request_id", "")


def build_envelope(
    *,
    code: str,
    success: bool,
    data: Any = None,
    message: str | None = None,
    errors: list[dict[str, str]] | None = None,
    meta: dict[str, Any] | None = None,
    request_id: str,
) -> dict[str, Any]:
    return {
        "code": code,
        "success": success,
        "data": data,
        "message": message,
        "errors": errors or [],
        "meta": meta or {},
        "request_id": request_id,
        "timestamp": utc_timestamp(),
    }


def api_response(
    request: Request,
    *,
    code: str,
    data: Any = None,
    message: str | None = None,
    errors: list[dict[str, str]] | None = None,
    meta: dict[str, Any] | None = None,
    status_code: int = 200,
    success: bool = True,
) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=build_envelope(
            code=code,
            success=success,
            data=data,
            message=message,
            errors=errors,
            meta=meta,
            request_id=request_id_of(request),
        ),
    )
