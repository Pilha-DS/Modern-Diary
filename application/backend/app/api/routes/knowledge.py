from urllib.parse import quote

from fastapi import APIRouter, Depends, File, Query, Request, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from atena_pattern.api.deps import get_actor
from atena_pattern.core.access import Actor
from atena_pattern.core.database import get_db
from atena_pattern.core.responses import api_response
from app.models.knowledge import KnowledgeItem
from app.schemas.knowledge import (
    GRAPH_MAX_NODES,
    MAX_ATTACHMENT_BYTES,
    AttachmentResponse,
    GoalReference,
    KnowledgeCreateRequest,
    KnowledgeGoalRequest,
    KnowledgeItemResponse,
    KnowledgeLink,
    KnowledgeObservationRequest,
    KnowledgeRelationRequest,
    KnowledgeUpdateRequest,
    ObservationResponse,
    RelationReference,
)
from atena_pattern.schemas.pagination import PageParams, pagination_meta
from app.services.knowledge_service import (
    KnowledgeDetails,
    KnowledgeService,
    find_attachment_for_download,
)

router = APIRouter(prefix="/knowledge", tags=["knowledge"])


def _item_payload(
    service: KnowledgeService,
    item: KnowledgeItem,
    details: KnowledgeDetails,
) -> dict:
    payload = KnowledgeItemResponse(
        id=item.id,
        title=item.title,
        content=item.content,
        links=[KnowledgeLink(**link) for link in (item.links or [])],
        sensitivity=item.sensitivity,
        relations=[
            RelationReference(id=related_id, title=title)
            for related_id, title in details.relations.get(item.id, [])
        ],
        goals=[
            GoalReference(id=goal_id, title=title)
            for goal_id, title in details.goals.get(item.id, [])
        ],
        tags=details.tags.get(item.id, []),
        attachments=[
            AttachmentResponse(
                id=row[0],
                filename=row[2],
                content_type=row[3],
                size_bytes=row[4],
                download_url=service.download_path(item.id, row[0]),
            )
            for row in details.attachments.get(item.id, [])
        ],
        observations=[
            ObservationResponse(
                id=observation.id,
                text=observation.text,
                created_at=observation.created_at,
            )
            for observation in details.observations.get(item.id, [])
        ],
        created_at=item.created_at,
        updated_at=item.updated_at,
    )
    return payload.model_dump(mode="json")


@router.get("", summary="Lista os conhecimentos paginados")
def list_items(
    request: Request,
    tag_id: int | None = Query(default=None, gt=0, description="Filtra por tag"),
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    service = KnowledgeService(session, actor)
    items, total = service.list_items(
        offset=page.offset,
        limit=page.per_page,
        tag_id=tag_id,
    )
    details = service.describe(items)
    return api_response(
        request,
        code="KNOWLEDGE_LISTED",
        data=[_item_payload(service, item, details) for item in items],
        meta=pagination_meta(page.page, page.per_page, total),
    )


@router.get("/graph", summary="Rede de conhecimentos para a visão em grafo")
def knowledge_graph(
    request: Request,
    tag_id: int | None = Query(default=None, gt=0, description="Filtra por tag"),
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    service = KnowledgeService(session, actor)
    graph = service.graph(tag_id)
    total = service.count_items(tag_id)
    return api_response(
        request,
        code="KNOWLEDGE_GRAPH",
        data=graph.model_dump(mode="json"),
        meta={
            "total": total,
            "max_nodes": GRAPH_MAX_NODES,
            "truncated": total > GRAPH_MAX_NODES,
        },
    )


@router.post("", status_code=201, summary="Cria um conhecimento")
def create_item(
    payload: KnowledgeCreateRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    service = KnowledgeService(session, actor)
    item = service.create_item(
        title=payload.title,
        content=payload.content,
        links=payload.links,
        sensitivity=payload.sensitivity,
        tag_ids=payload.tag_ids,
    )
    details = service.describe([item])
    return api_response(
        request,
        code="KNOWLEDGE_CREATED",
        data=_item_payload(service, item, details),
        message="Conhecimento criado com sucesso.",
        status_code=201,
    )


@router.get("/{item_id}", summary="Detalhe de um conhecimento")
def get_item(
    item_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    service = KnowledgeService(session, actor)
    item = service.get_item(item_id)
    details = service.describe([item])
    return api_response(
        request,
        code="KNOWLEDGE_RETRIEVED",
        data=_item_payload(service, item, details),
    )


@router.patch("/{item_id}", summary="Atualiza um conhecimento")
def update_item(
    item_id: int,
    payload: KnowledgeUpdateRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    service = KnowledgeService(session, actor)
    item = service.update_item(
        item_id,
        title=payload.title,
        content=payload.content,
        change_content="content" in payload.model_fields_set,
        links=payload.links,
        change_links="links" in payload.model_fields_set,
        sensitivity=payload.sensitivity,
        tag_ids=payload.tag_ids,
        change_tags="tag_ids" in payload.model_fields_set,
    )
    details = service.describe([item])
    return api_response(
        request,
        code="KNOWLEDGE_UPDATED",
        data=_item_payload(service, item, details),
        message="Conhecimento atualizado com sucesso.",
    )


@router.delete("/{item_id}", summary="Exclui um conhecimento")
def delete_item(
    item_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    KnowledgeService(session, actor).delete_item(item_id)
    return api_response(
        request,
        code="KNOWLEDGE_DELETED",
        data={"id": item_id},
        message="Conhecimento excluído com sucesso.",
    )


@router.post(
    "/{item_id}/relations",
    status_code=201,
    summary="Conecta dois conhecimentos",
)
def create_relation(
    item_id: int,
    payload: KnowledgeRelationRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    source, target = KnowledgeService(session, actor).add_relation(
        item_id, payload.target_id
    )
    return api_response(
        request,
        code="KNOWLEDGE_RELATION_CREATED",
        data={"source_id": source, "target_id": target},
        message="Conhecimentos conectados.",
        status_code=201,
    )


@router.delete(
    "/{item_id}/relations/{target_id}",
    summary="Desfaz a conexão entre dois conhecimentos",
)
def delete_relation(
    item_id: int,
    target_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    KnowledgeService(session, actor).remove_relation(item_id, target_id)
    return api_response(
        request,
        code="KNOWLEDGE_RELATION_DELETED",
        data={"source_id": item_id, "target_id": target_id},
        message="Conexão removida.",
    )


@router.post(
    "/{item_id}/goals",
    status_code=201,
    summary="Liga uma meta ao conhecimento",
)
def create_goal_link(
    item_id: int,
    payload: KnowledgeGoalRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    item, goal = KnowledgeService(session, actor).add_goal(
        item_id, payload.goal_id
    )
    return api_response(
        request,
        code="KNOWLEDGE_GOAL_LINKED",
        data={"item_id": item, "goal_id": goal},
        message="Meta ligada ao conhecimento.",
        status_code=201,
    )


@router.delete(
    "/{item_id}/goals/{goal_id}",
    summary="Desfaz a ligação entre conhecimento e meta",
)
def delete_goal_link(
    item_id: int,
    goal_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    KnowledgeService(session, actor).remove_goal(item_id, goal_id)
    return api_response(
        request,
        code="KNOWLEDGE_GOAL_UNLINKED",
        data={"item_id": item_id, "goal_id": goal_id},
        message="Ligação com a meta removida.",
    )


@router.post(
    "/{item_id}/observations",
    status_code=201,
    summary="Adiciona uma observação ao conhecimento",
)
def create_observation(
    item_id: int,
    payload: KnowledgeObservationRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    observation = KnowledgeService(session, actor).add_observation(
        item_id, payload.text
    )
    return api_response(
        request,
        code="KNOWLEDGE_OBSERVATION_CREATED",
        data=ObservationResponse(
            id=observation.id,
            text=observation.text,
            created_at=observation.created_at,
        ).model_dump(mode="json"),
        message="Observação adicionada.",
        status_code=201,
    )


@router.delete(
    "/{item_id}/observations/{observation_id}",
    summary="Remove uma observação do conhecimento",
)
def delete_observation(
    item_id: int,
    observation_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    KnowledgeService(session, actor).delete_observation(item_id, observation_id)
    return api_response(
        request,
        code="KNOWLEDGE_OBSERVATION_DELETED",
        data={"id": observation_id},
        message="Observação removida.",
    )


@router.post(
    "/{item_id}/attachments",
    status_code=201,
    summary="Anexa um arquivo ao conhecimento",
)
async def create_attachment(
    item_id: int,
    request: Request,
    file: UploadFile = File(description="Arquivo de até 5 MB"),
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    content = await file.read(MAX_ATTACHMENT_BYTES + 1)
    service = KnowledgeService(session, actor)
    attachment = service.add_attachment(
        item_id,
        filename=file.filename or "anexo",
        content_type=file.content_type or "application/octet-stream",
        content=content,
    )
    return api_response(
        request,
        code="KNOWLEDGE_ATTACHMENT_CREATED",
        data=AttachmentResponse(
            id=attachment.id,
            filename=attachment.filename,
            content_type=attachment.content_type,
            size_bytes=attachment.size_bytes,
            download_url=service.download_path(item_id, attachment.id),
        ).model_dump(mode="json"),
        message="Anexo adicionado com sucesso.",
        status_code=201,
    )


@router.delete(
    "/{item_id}/attachments/{attachment_id}",
    summary="Remove um anexo",
)
def delete_attachment(
    item_id: int,
    attachment_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    KnowledgeService(session, actor).delete_attachment(item_id, attachment_id)
    return api_response(
        request,
        code="KNOWLEDGE_ATTACHMENT_DELETED",
        data={"id": attachment_id},
        message="Anexo removido com sucesso.",
    )


@router.get(
    "/{item_id}/attachments/{attachment_id}/download",
    summary="Baixa um anexo por link temporário",
)
def download_attachment(
    item_id: int,
    attachment_id: int,
    token: str = Query(description="Token temporário do anexo"),
    session: Session = Depends(get_db),
):
    attachment = find_attachment_for_download(
        session, token, item_id, attachment_id
    )
    filename = quote(attachment.filename)
    return Response(
        content=attachment.content,
        media_type=attachment.content_type,
        headers={
            "Content-Disposition": f"inline; filename*=UTF-8''{filename}",
            "Cache-Control": "private, no-store",
        },
    )
