import logging
import re
import time
from uuid import uuid4

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

from app.core.request_context import reset_request_id, set_request_id

REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,64}$")
REQUEST_ID_HEADER = "X-Request-ID"

logger = logging.getLogger("modern_diary.request")


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

        started_at = time.perf_counter()
        try:
            response = await call_next(request)
        finally:
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
