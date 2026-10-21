from datetime import date
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.goal import Goal, GoalStatus, GoalStep
from app.models.sensitivity import Sensitivity
from app.schemas.sensitivity import DataLevel
from app.schemas.tag import MAX_TAGS_PER_TARGET, TagSummary

MAX_STEPS_PER_GOAL = 50
MAX_TITLE_LENGTH = 120
MAX_DESCRIPTION_LENGTH = 2000


class GoalView(StrEnum):
    """Filtro de listagem: a meta está ativa, concluída ou arquivada."""

    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    ARCHIVED = "ARCHIVED"


def _clean_title(value: str) -> str:
    stripped = value.strip()
    if not stripped:
        raise ValueError("título vazio")
    return stripped


def _clean_description(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


class GoalStepCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=MAX_TITLE_LENGTH)

    @field_validator("title")
    @classmethod
    def strip_title(cls, value: str) -> str:
        return _clean_title(value)


class GoalCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=MAX_TITLE_LENGTH)
    description: str | None = Field(default=None, max_length=MAX_DESCRIPTION_LENGTH)
    due_date: date | None = None
    steps: list[GoalStepCreateRequest] = Field(
        default_factory=list,
        max_length=MAX_STEPS_PER_GOAL,
    )
    tag_ids: list[int] = Field(default_factory=list, max_length=MAX_TAGS_PER_TARGET)
    sensitivity: DataLevel = Sensitivity.PUBLIC

    @field_validator("title")
    @classmethod
    def strip_title(cls, value: str) -> str:
        return _clean_title(value)

    @field_validator("description")
    @classmethod
    def strip_description(cls, value: str | None) -> str | None:
        return _clean_description(value)


class GoalUpdateRequest(BaseModel):
    """Campo ausente não muda; `due_date: null` limpa o prazo."""

    title: str | None = Field(default=None, min_length=1, max_length=MAX_TITLE_LENGTH)
    description: str | None = Field(default=None, max_length=MAX_DESCRIPTION_LENGTH)
    due_date: date | None = None
    is_completed: bool | None = None
    is_archived: bool | None = None
    tag_ids: list[int] | None = Field(default=None, max_length=MAX_TAGS_PER_TARGET)
    sensitivity: DataLevel | None = None

    @field_validator("title")
    @classmethod
    def strip_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _clean_title(value)

    @field_validator("description")
    @classmethod
    def strip_description(cls, value: str | None) -> str | None:
        return _clean_description(value)


class GoalStepUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=MAX_TITLE_LENGTH)
    is_done: bool | None = None

    @field_validator("title")
    @classmethod
    def strip_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _clean_title(value)


class GoalStepResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    is_done: bool
    position: int


class GoalResponse(BaseModel):
    id: int
    title: str
    description: str | None
    due_date: date | None
    sensitivity: DataLevel
    is_completed: bool
    is_archived: bool
    progress_done: int
    progress_total: int
    steps: list[GoalStepResponse]
    tags: list[TagSummary]

    @classmethod
    def from_model(
        cls,
        goal: Goal,
        tags: list[TagSummary] | None = None,
    ) -> "GoalResponse":
        steps = [GoalStepResponse.model_validate(step) for step in goal.steps]
        return cls(
            id=goal.id,
            title=goal.title,
            description=goal.description,
            due_date=goal.due_date,
            sensitivity=goal.sensitivity,
            is_completed=goal.status == GoalStatus.COMPLETED,
            is_archived=goal.archived_at is not None,
            **_progress_of(goal, steps),
            steps=steps,
            tags=tags or [],
        )


def _progress_of(goal: Goal, steps: list[GoalStepResponse]) -> dict[str, int]:
    """Sem etapas, a própria meta é a unidade concluída.

    Assim a contagem e a barra nunca ficam em `0/0`.
    """
    if steps:
        return {
            "progress_done": sum(1 for step in steps if step.is_done),
            "progress_total": len(steps),
        }
    return {
        "progress_done": 1 if goal.status == GoalStatus.COMPLETED else 0,
        "progress_total": 1,
    }


def step_payload(step: GoalStep) -> dict:
    return GoalStepResponse.model_validate(step).model_dump(mode="json")
