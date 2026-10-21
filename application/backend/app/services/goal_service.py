from datetime import date

from sqlalchemy.orm import Session

from app.core.access import AccessGuard, Actor
from app.core.errors import AppError
from app.models.api_secret import AuditAction
from app.models.area import Area
from app.models.goal import Goal, GoalStatus, GoalStep
from app.models.sensitivity import Sensitivity
from app.models.tag import TagTarget
from app.models.user import utc_now
from app.repositories.goal_repository import GoalRepository
from app.schemas.goal import MAX_STEPS_PER_GOAL, GoalView
from app.schemas.tag import TagSummary
from app.services.tag_service import TagService

MAX_GOALS_PER_USER = 500


class GoalService:
    def __init__(self, session: Session, actor: Actor) -> None:
        self.session = session
        self.actor = actor
        self.access = AccessGuard(session, actor)
        self.goals = GoalRepository(session)
        self.tags = TagService(session)

    def list_page(
        self,
        view: GoalView,
        *,
        offset: int,
        limit: int,
        tag_id: int | None = None,
    ) -> tuple[list[Goal], int]:
        return self.goals.list_page(
            self.actor.user_id,
            view,
            offset,
            limit,
            tag_id,
            self.access.visible(Area.GOAL),
        )

    def get_goal(self, goal_id: int) -> Goal:
        return self._get_goal_or_fail(goal_id)

    def counts(self, tag_id: int | None = None) -> dict[str, int]:
        return self.goals.counts(
            self.actor.user_id,
            tag_id,
            self.access.visible(Area.GOAL),
        )

    def tags_for(self, goals: list[Goal]) -> dict[int, list[TagSummary]]:
        return self.tags.tags_for_targets(
            self.actor.user_id,
            TagTarget.GOAL,
            [goal.id for goal in goals],
        )

    def create_goal(
        self,
        *,
        title: str,
        description: str | None,
        due_date: date | None,
        sensitivity: Sensitivity,
        steps: list[str],
        tag_ids: list[int] | None = None,
    ) -> Goal:
        self.access.ensure_create(Area.GOAL, target_type="goal")
        if self.goals.count_goals(self.actor.user_id) >= MAX_GOALS_PER_USER:
            raise AppError(
                code="GOAL_LIMIT",
                message="Você já atingiu o limite de metas.",
                status_code=409,
            )
        if len(steps) > MAX_STEPS_PER_GOAL:
            raise AppError(
                code="GOAL_STEP_LIMIT",
                message=f"Cada meta aceita no máximo {MAX_STEPS_PER_GOAL} etapas.",
                status_code=422,
            )

        goal = Goal(
            user_id=self.actor.user_id,
            title=title,
            description=description,
            due_date=due_date,
            sensitivity=sensitivity,
        )
        for position, step_title in enumerate(steps, start=1):
            goal.steps.append(GoalStep(title=step_title, position=position))

        self.goals.add(goal)
        self.session.flush()
        self.access.record_created(Area.GOAL, "goal", goal.id)
        if tag_ids:
            self.tags.set_tags(self.actor.user_id, TagTarget.GOAL, goal.id, tag_ids)
        self.session.commit()
        return goal

    def update_goal(
        self,
        goal_id: int,
        *,
        title: str | None = None,
        description: str | None = None,
        change_description: bool = False,
        due_date: date | None = None,
        change_due_date: bool = False,
        is_completed: bool | None = None,
        is_archived: bool | None = None,
        sensitivity: Sensitivity | None = None,
        tag_ids: list[int] | None = None,
        change_tags: bool = False,
    ) -> Goal:
        goal = self._get_goal_or_fail(goal_id)
        self.access.ensure_write(
            Area.GOAL,
            goal.sensitivity,
            target_type="goal",
            target_id=goal.id,
        )

        if title is not None:
            goal.title = title
        if change_description:
            goal.description = description
        if change_due_date:
            goal.due_date = due_date
        if is_completed is not None:
            self._set_completed(goal, is_completed)
        if is_archived is not None:
            if is_archived and goal.archived_at is None:
                goal.archived_at = utc_now()
            elif not is_archived:
                goal.archived_at = None
        if sensitivity is not None:
            self.access.ensure_new_level(Area.GOAL, sensitivity)
            goal.sensitivity = sensitivity
        if change_tags:
            self.tags.set_tags(
                self.actor.user_id,
                TagTarget.GOAL,
                goal.id,
                tag_ids or [],
            )

        self.session.commit()
        return goal

    def delete_goal(self, goal_id: int) -> None:
        goal = self._get_goal_or_fail(goal_id)
        self.access.ensure_write(
            Area.GOAL,
            goal.sensitivity,
            target_type="goal",
            target_id=goal.id,
            action=AuditAction.DELETE,
        )
        self.goals.delete_knowledge_links(goal_id)
        self.tags.remove_target_links(TagTarget.GOAL, goal_id)
        self.goals.remove(goal)
        self.session.commit()

    def add_step(self, goal_id: int, *, title: str) -> GoalStep:
        goal = self._get_goal_or_fail(goal_id)
        self.access.ensure_write(
            Area.GOAL,
            goal.sensitivity,
            target_type="goal",
            target_id=goal.id,
        )
        if self.goals.count_steps(goal.id) >= MAX_STEPS_PER_GOAL:
            raise AppError(
                code="GOAL_STEP_LIMIT",
                message=f"Cada meta aceita no máximo {MAX_STEPS_PER_GOAL} etapas.",
                status_code=409,
            )

        step = GoalStep(
            goal_id=goal.id,
            title=title,
            position=self.goals.next_position(goal.id),
        )
        self.goals.add(step)
        self.session.commit()
        return step

    def update_step(
        self,
        goal_id: int,
        step_id: int,
        *,
        title: str | None = None,
        is_done: bool | None = None,
    ) -> GoalStep:
        step = self._get_step_or_fail(goal_id, step_id)
        goal = self._get_goal_or_fail(goal_id)
        self.access.ensure_write(
            Area.GOAL,
            goal.sensitivity,
            target_type="goal",
            target_id=goal.id,
        )
        if title is not None:
            step.title = title
        if is_done is not None:
            step.is_done = is_done
        self.session.commit()
        return step

    def delete_step(self, goal_id: int, step_id: int) -> None:
        step = self._get_step_or_fail(goal_id, step_id)
        goal = self._get_goal_or_fail(goal_id)
        self.access.ensure_write(
            Area.GOAL,
            goal.sensitivity,
            target_type="goal",
            target_id=goal.id,
            action=AuditAction.DELETE,
        )
        self.goals.remove(step)
        self.session.commit()

    @staticmethod
    def _set_completed(goal: Goal, is_completed: bool) -> None:
        if is_completed and goal.status is not GoalStatus.COMPLETED:
            goal.status = GoalStatus.COMPLETED
            goal.completed_at = utc_now()
        elif not is_completed:
            goal.status = GoalStatus.ACTIVE
            goal.completed_at = None

    def _get_goal_or_fail(self, goal_id: int) -> Goal:
        goal = self.goals.get(
            self.actor.user_id,
            goal_id,
            self.access.visible(Area.GOAL),
        )
        if goal is None:
            raise AppError(
                code="GOAL_NOT_FOUND",
                message="Meta não encontrada.",
                status_code=404,
            )
        return goal

    def _get_step_or_fail(self, goal_id: int, step_id: int) -> GoalStep:
        step = self.goals.get_step(
            self.actor.user_id,
            goal_id,
            step_id,
            self.access.visible(Area.GOAL),
        )
        if step is None:
            raise AppError(
                code="GOAL_STEP_NOT_FOUND",
                message="Etapa não encontrada.",
                status_code=404,
            )
        return step
