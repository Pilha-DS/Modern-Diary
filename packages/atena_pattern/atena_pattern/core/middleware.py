import logging
import re
import time
from uuid import uuid4

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

from atena_pattern.core.request_context import (
    reset_client_offset_minutes,
    reset_request_id,
    set_client_offset_minutes,
    set_request_id,
)

REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,64}$")
REQUEST_ID_HEADER = "X-Request-ID"
CLIENT_OFFSET_HEADER = "X-Client-Offset-Minutes"


def _parse_offset(raw: str) -> int:
    try:
        return int(raw)
    except ValueError:
        return 0

logger = logging.getLogger("atena_pattern.request")


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        incoming_request_id = request.headers.get(REQUEST_ID_HEADER, "")
        request_id = (
            incoming_request_id
            if REQUEST_ID_PATTERN.fullmatch(incoming_request_id)
            else f"req_{uuid4().hex}"
        )
        request.state.request_id = request_id
        request_id_token = set_request_id(request_id)
        offset_token = set_client_offset_minutes(
            _parse_offset(request.headers.get(CLIENT_OFFSET_HEADER, ""))
        )

        started_at = time.perf_counter()
        try:
            response = await call_next(request)
        finally:
            reset_client_offset_minutes(offset_token)
            reset_request_id(request_id_token)
        duration_ms = (time.perf_counter() - started_at) * 1000

        response.headers[REQUEST_ID_HEADER] = request_id
        logger.info(
            "method=%s path=%s status=%s duration_ms=%.1f request_id=%s",
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
            request_id,
        )
        return response
