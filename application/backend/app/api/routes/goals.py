from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.api.deps import get_actor
from app.core.access import Actor
from app.core.database import get_db
from app.core.responses import api_response
from app.schemas.goal import (
    GoalCreateRequest,
    GoalResponse,
    GoalStepCreateRequest,
    GoalStepUpdateRequest,
    GoalUpdateRequest,
    GoalView,
    step_payload,
)
from app.schemas.pagination import PageParams, pagination_meta
from app.services.goal_service import GoalService

router = APIRouter(prefix="/goals", tags=["goals"])


@router.get("", summary="Lista as metas paginadas por situação")
def list_goals(
    request: Request,
    status: GoalView = Query(default=GoalView.ACTIVE, description="Situação da meta"),
    tag_id: int | None = Query(default=None, gt=0, description="Filtra por tag"),
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    service = GoalService(session, actor)
    goals, total = service.list_page(
        status,
        offset=page.offset,
        limit=page.per_page,
        tag_id=tag_id,
    )
    tags = service.tags_for(goals)
    return api_response(
        request,
        code="GOALS_LISTED",
        data=[
            GoalResponse.from_model(goal, tags.get(goal.id, [])).model_dump(
                mode="json"
            )
            for goal in goals
        ],
        meta={
            **pagination_meta(page.page, page.per_page, total),
            "counts": service.counts(tag_id),
        },
    )


@router.post("", status_code=201, summary="Cria uma meta com etapas opcionais")
def create_goal(
    payload: GoalCreateRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    service = GoalService(session, actor)
    goal = service.create_goal(
        title=payload.title,
        description=payload.description,
        due_date=payload.due_date,
        sensitivity=payload.sensitivity,
        steps=[step.title for step in payload.steps],
        tag_ids=payload.tag_ids,
    )
    tags = service.tags_for([goal])
    return api_response(
        request,
        code="GOAL_CREATED",
        data=GoalResponse.from_model(goal, tags.get(goal.id, [])).model_dump(
            mode="json"
        ),
        message="Meta criada com sucesso.",
        status_code=201,
    )


@router.get("/{goal_id}", summary="Detalha uma meta pelo identificador")
def get_goal(
    goal_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    service = GoalService(session, actor)
    goal = service.get_goal(goal_id)
    tags = service.tags_for([goal])
    return api_response(
        request,
        code="GOAL_FOUND",
        data=GoalResponse.from_model(goal, tags.get(goal.id, [])).model_dump(
            mode="json"
        ),
    )


@router.patch("/{goal_id}", summary="Atualiza, conclui ou arquiva uma meta")
def update_goal(
    goal_id: int,
    payload: GoalUpdateRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    service = GoalService(session, actor)
    goal = service.update_goal(
        goal_id,
        title=payload.title,
        description=payload.description,
        change_description="description" in payload.model_fields_set,
        due_date=payload.due_date,
        change_due_date="due_date" in payload.model_fields_set,
        is_completed=payload.is_completed,
        is_archived=payload.is_archived,
        sensitivity=payload.sensitivity,
        tag_ids=payload.tag_ids,
        change_tags="tag_ids" in payload.model_fields_set,
    )
    tags = service.tags_for([goal])
    return api_response(
        request,
        code="GOAL_UPDATED",
        data=GoalResponse.from_model(goal, tags.get(goal.id, [])).model_dump(
            mode="json"
        ),
        message="Meta atualizada com sucesso.",
    )


@router.delete("/{goal_id}", summary="Exclui uma meta e suas etapas")
def delete_goal(
    goal_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    GoalService(session, actor).delete_goal(goal_id)
    return api_response(
        request,
        code="GOAL_DELETED",
        data={"id": goal_id},
        message="Meta excluída com sucesso.",
    )


@router.post("/{goal_id}/steps", status_code=201, summary="Adiciona uma etapa")
def create_step(
    goal_id: int,
    payload: GoalStepCreateRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    step = GoalService(session, actor).add_step(goal_id, title=payload.title)
    return api_response(
        request,
        code="GOAL_STEP_CREATED",
        data=step_payload(step),
        message="Etapa criada com sucesso.",
        status_code=201,
    )


@router.patch("/{goal_id}/steps/{step_id}", summary="Atualiza uma etapa")
def update_step(
    goal_id: int,
    step_id: int,
    payload: GoalStepUpdateRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    step = GoalService(session, actor).update_step(
        goal_id,
        step_id,
        title=payload.title,
        is_done=payload.is_done,
    )
    return api_response(
        request,
        code="GOAL_STEP_UPDATED",
        data=step_payload(step),
        message="Etapa atualizada com sucesso.",
    )


@router.delete("/{goal_id}/steps/{step_id}", summary="Exclui uma etapa")
def delete_step(
    goal_id: int,
    step_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    GoalService(session, actor).delete_step(goal_id, step_id)
    return api_response(
        request,
        code="GOAL_STEP_DELETED",
        data={"id": step_id},
        message="Etapa excluída com sucesso.",
    )
