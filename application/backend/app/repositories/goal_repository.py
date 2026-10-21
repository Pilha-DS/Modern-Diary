from sqlalchemy import and_, case, delete, func, select
from sqlalchemy.orm import Session

from app.models.goal import Goal, GoalStatus, GoalStep
from app.models.knowledge import KnowledgeGoalLink
from app.models.tag import Tag, TagLink, TagTarget
from app.schemas.goal import GoalView


class GoalRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get(
        self, user_id: int, goal_id: int, criteria: list | None = None
    ) -> Goal | None:
        return self.session.scalar(
            select(Goal).where(
                Goal.id == goal_id,
                Goal.user_id == user_id,
                *(criteria or []),
            )
        )

    def list_page(
        self,
        user_id: int,
        view: GoalView,
        offset: int,
        limit: int,
        tag_id: int | None = None,
        criteria: list | None = None,
    ) -> tuple[list[Goal], int]:
        filters = [
            *self._criteria(user_id, view, tag_id),
            *(criteria or []),
        ]
        total = (
            self.session.scalar(select(func.count(Goal.id)).where(*filters)) or 0
        )
        goals = list(
            self.session.scalars(
                select(Goal)
                .where(*filters)
                .order_by(Goal.created_at.desc(), Goal.id.desc())
                .offset(offset)
                .limit(limit)
            ).all()
        )
        return goals, total

    def counts(
        self,
        user_id: int,
        tag_id: int | None = None,
        criteria: list | None = None,
    ) -> dict[str, int]:
        filters = [Goal.user_id == user_id, *(criteria or [])]
        if tag_id is not None:
            filters.append(
                Goal.id.in_(
                    select(TagLink.target_id)
                    .join(Tag, Tag.id == TagLink.tag_id)
                    .where(
                        Tag.user_id == user_id,
                        TagLink.target_type == TagTarget.GOAL,
                        TagLink.tag_id == tag_id,
                    )
                )
            )
        row = self.session.execute(
            select(
                func.coalesce(
                    func.sum(
                        case(
                            (
                                and_(
                                    Goal.archived_at.is_(None),
                                    Goal.status == GoalStatus.ACTIVE,
                                ),
                                1,
                            ),
                            else_=0,
                        )
                    ),
                    0,
                ),
                func.coalesce(
                    func.sum(
                        case(
                            (
                                and_(
                                    Goal.archived_at.is_(None),
                                    Goal.status == GoalStatus.COMPLETED,
                                ),
                                1,
                            ),
                            else_=0,
                        )
                    ),
                    0,
                ),
                func.coalesce(
                    func.sum(case((Goal.archived_at.is_not(None), 1), else_=0)),
                    0,
                ),
            ).where(*filters)
        ).one()

        return {
            GoalView.ACTIVE: int(row[0]),
            GoalView.COMPLETED: int(row[1]),
            GoalView.ARCHIVED: int(row[2]),
        }

    def count_goals(self, user_id: int) -> int:
        return (
            self.session.scalar(
                select(func.count(Goal.id)).where(Goal.user_id == user_id)
            )
            or 0
        )

    def count_steps(self, goal_id: int) -> int:
        return (
            self.session.scalar(
                select(func.count(GoalStep.id)).where(GoalStep.goal_id == goal_id)
            )
            or 0
        )

    def next_position(self, goal_id: int) -> int:
        highest = self.session.scalar(
            select(func.max(GoalStep.position)).where(GoalStep.goal_id == goal_id)
        )
        return (highest or 0) + 1

    def get_step(
        self,
        user_id: int,
        goal_id: int,
        step_id: int,
        criteria: list | None = None,
    ) -> GoalStep | None:
        return self.session.scalar(
            select(GoalStep)
            .join(Goal, Goal.id == GoalStep.goal_id)
            .where(
                GoalStep.id == step_id,
                GoalStep.goal_id == goal_id,
                Goal.user_id == user_id,
                *(criteria or []),
            )
        )

    def add(self, row: Goal | GoalStep) -> None:
        self.session.add(row)

    def remove(self, row: Goal | GoalStep) -> None:
        self.session.delete(row)

    def delete_knowledge_links(self, goal_id: int) -> None:
        self.session.execute(
            delete(KnowledgeGoalLink).where(KnowledgeGoalLink.goal_id == goal_id)
        )

    @staticmethod
    def _criteria(user_id: int, view: GoalView, tag_id: int | None = None) -> list:
        criteria: list = [Goal.user_id == user_id]
        if view is GoalView.ARCHIVED:
            criteria.append(Goal.archived_at.is_not(None))
        else:
            criteria.append(Goal.archived_at.is_(None))
            criteria.append(
                Goal.status == (
                    GoalStatus.ACTIVE
                    if view is GoalView.ACTIVE
                    else GoalStatus.COMPLETED
                )
            )
        if tag_id is not None:
            criteria.append(
                Goal.id.in_(
                    select(TagLink.target_id)
                    .join(Tag, Tag.id == TagLink.tag_id)
                    .where(
                        Tag.user_id == user_id,
                        TagLink.target_type == TagTarget.GOAL,
                        TagLink.tag_id == tag_id,
                    )
                )
            )
        return criteria
