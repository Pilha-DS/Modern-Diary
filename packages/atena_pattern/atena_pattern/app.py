import logging
from collections.abc import Iterable

from fastapi import APIRouter, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from atena_pattern.api.router import base_router
from atena_pattern.core.config import AthenaSettings, configure, get_settings
from atena_pattern.core.database import configure_database, database_is_configured
from atena_pattern.core.errors import AppError, FieldError
from atena_pattern.core.middleware import RequestIdMiddleware
from atena_pattern.core.responses import api_response

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

logger = logging.getLogger("atena_pattern")

HTTP_ERROR_CODES = {
    400: "BAD_REQUEST",
    401: "UNAUTHORIZED",
    403: "FORBIDDEN",
    404: "NOT_FOUND",
    405: "METHOD_NOT_ALLOWED",
    409: "CONFLICT",
    422: "VALIDATION_ERROR",
    429: "RATE_LIMITED",
    500: "INTERNAL_ERROR",
}

HTTP_ERROR_MESSAGES = {
    400: "Requisição inválida.",
    401: "Faça login para continuar.",
    403: "Você não tem permissão para executar esta ação.",
    404: "Recurso não encontrado.",
    405: "Método não permitido.",
    409: "A requisição conflita com o estado atual.",
    422: "Dados inválidos.",
    429: "Muitas requisições. Tente novamente em instantes.",
    500: "Não foi possível concluir a operação.",
}

VALIDATION_MESSAGES = {
    "missing": ("REQUIRED", "Campo obrigatório."),
    "string_too_short": ("TOO_SHORT", "Texto muito curto."),
    "string_too_long": ("TOO_LONG", "Texto muito longo."),
    "string_pattern_mismatch": ("INVALID_FORMAT", "Formato inválido."),
    "literal_error": ("INVALID_VALUE", "Valor não permitido."),
    "int_parsing": ("INVALID_TYPE", "Informe um número inteiro."),
    "greater_than_equal": ("TOO_SMALL", "Valor abaixo do mínimo permitido."),
    "less_than_equal": ("TOO_LARGE", "Valor acima do máximo permitido."),
    "json_invalid": ("INVALID_JSON", "Corpo da requisição inválido."),
}


def validation_errors(exc: RequestValidationError) -> list[FieldError]:
    errors: list[FieldError] = []
    for error in exc.errors():
        location = [str(part) for part in error.get("loc", ()) if part != "body"]
        field = ".".join(location) or "body"
        code, message = VALIDATION_MESSAGES.get(
            error.get("type", ""),
            ("INVALID_VALUE", "Valor inválido."),
        )
        errors.append(FieldError(field=field, code=code, message=message))
    return errors


async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    return api_response(
        request,
        code=exc.code,
        message=exc.message,
        errors=[
            {"field": error.field, "code": error.code, "message": error.message}
            for error in exc.errors
        ],
        status_code=exc.status_code,
        success=False,
    )


async def validation_error_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    return api_response(
        request,
        code="VALIDATION_ERROR",
        message="Verifique os campos informados.",
        errors=[
            {"field": error.field, "code": error.code, "message": error.message}
            for error in validation_errors(exc)
        ],
        status_code=422,
        success=False,
    )


async def http_error_handler(
    request: Request, exc: StarletteHTTPException
) -> JSONResponse:
    message = (
        exc.detail
        if isinstance(exc.detail, str) and exc.detail
        else HTTP_ERROR_MESSAGES.get(
            exc.status_code, "Não foi possível concluir a operação."
        )
    )
    return api_response(
        request,
        code=HTTP_ERROR_CODES.get(exc.status_code, "ERROR"),
        message=message,
        status_code=exc.status_code,
        success=False,
    )


async def unhandled_error_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception(
        "unhandled_error request_id=%s",
        getattr(request.state, "request_id", ""),
        exc_info=True,
    )
    return api_response(
        request,
        code="INTERNAL_ERROR",
        message="Não foi possível concluir a operação. Tente novamente.",
        status_code=500,
        success=False,
    )


def create_app(
    settings: AthenaSettings | None = None,
    *,
    routers: Iterable[APIRouter] = (),
    api_prefix: str = "/api/v1",
    title: str | None = None,
) -> FastAPI:
    """Monta a aplicação com o núcleo do padrão.

    O projeto passa as próprias rotas em `routers`; elas entram sob o mesmo
    `api_prefix` das rotas herdadas (auth, users e secrets).
    """
    configured = configure(settings) if settings is not None else get_settings()
    if not database_is_configured():
        configure_database(configured.database_url)

    app = FastAPI(
        title=title or configured.app_name,
        version="0.1.0",
        docs_url="/docs",
        redoc_url="/redoc",
    )

    cors_origins = configured.cors_origin_list
    if not cors_origins and configured.environment == "development":
        cors_origins = ["*"]

    app.add_middleware(RequestIdMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-Request-ID"],
    )

    app.add_exception_handler(AppError, app_error_handler)
    app.add_exception_handler(RequestValidationError, validation_error_handler)
    app.add_exception_handler(StarletteHTTPException, http_error_handler)
    app.add_exception_handler(Exception, unhandled_error_handler)

    api = APIRouter(prefix=api_prefix)
    api.include_router(base_router)
    for router in routers:
        api.include_router(router)
    app.include_router(api)

    @app.get("/health", tags=["health"], summary="Verifica se a API está no ar")
    def health(request: Request) -> JSONResponse:
        return api_response(request, code="HEALTHY", data={"status": "ok"})

    return app
