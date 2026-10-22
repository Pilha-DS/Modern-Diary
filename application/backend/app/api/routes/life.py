from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.api.deps import get_actor
from app.core.access import Actor
from app.core.database import get_db
from app.core.errors import AppError
from app.core.responses import api_response
from app.models.life_link import LinkType
from app.schemas.life import LifeLinkRequest
from app.services.life_service import MAX_NODES_PER_TYPE, LifeService

router = APIRouter(prefix="/life", tags=["life"])


def _types(raw: str | None) -> list[LinkType] | None:
    if not raw:
        return None
    selected: list[LinkType] = []
    for value in raw.split(","):
        try:
            link_type = LinkType(value.strip())
        except ValueError as error:
            raise AppError(
                code="LIFE_INVALID_TYPE",
                message="Tipo de registro desconhecido no filtro.",
                status_code=422,
            ) from error
        if link_type not in selected:
            selected.append(link_type)
    return selected


@router.get("/graph", summary="Grafo de vida com tudo que o usuário registrou")
def life_graph(
    request: Request,
    types: str | None = Query(
        default=None,
        description="Tipos separados por vírgula: knowledge,goal,note,activity,day",
    ),
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    graph = LifeService(session, actor).graph(_types(types))
    return api_response(
        request,
        code="LIFE_GRAPH",
        data=graph.model_dump(mode="json"),
        meta={
            "max_nodes_per_type": MAX_NODES_PER_TYPE,
            "truncated": graph.truncated,
        },
    )


@router.post("/links", status_code=201, summary="Conecta dois registros")
def create_link(
    payload: LifeLinkRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    link = LifeService(session, actor).link(payload)
    return api_response(
        request,
        code="LIFE_LINK_CREATED",
        data={
            "source": f"{link.source_type.value}:{link.source_ref}",
            "target": f"{link.target_type.value}:{link.target_ref}",
        },
        message="Registros conectados.",
        status_code=201,
    )


@router.delete("/links", summary="Desfaz a conexão entre dois registros")
def delete_link(
    payload: LifeLinkRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    LifeService(session, actor).unlink(payload)
    return api_response(
        request,
        code="LIFE_LINK_DELETED",
        data={
            "source": f"{payload.source_type.value}:{payload.source_ref}",
            "target": f"{payload.target_type.value}:{payload.target_ref}",
        },
        message="Conexão removida.",
    )
