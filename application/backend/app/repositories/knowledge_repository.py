from sqlalchemy import delete, func, or_, select
from sqlalchemy.orm import Session

from app.models.goal import Goal
from app.models.knowledge import (
    KnowledgeAttachment,
    KnowledgeGoalLink,
    KnowledgeItem,
    KnowledgeRelation,
)
from app.models.tag import Tag, TagLink, TagTarget


class KnowledgeRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get(
        self, user_id: int, item_id: int, criteria: list | None = None
    ) -> KnowledgeItem | None:
        return self.session.scalar(
            select(KnowledgeItem).where(
                KnowledgeItem.id == item_id,
                KnowledgeItem.user_id == user_id,
                *(criteria or []),
            )
        )

    def list_page(
        self,
        user_id: int,
        offset: int,
        limit: int,
        tag_id: int | None = None,
        criteria: list | None = None,
    ) -> tuple[list[KnowledgeItem], int]:
        filters = [
            *self._criteria(user_id, tag_id),
            *(criteria or []),
        ]
        total = self.session.scalar(
            select(func.count(KnowledgeItem.id)).where(*filters)
        ) or 0
        items = list(
            self.session.scalars(
                select(KnowledgeItem)
                .where(*filters)
                .order_by(KnowledgeItem.updated_at.desc(), KnowledgeItem.id.desc())
                .offset(offset)
                .limit(limit)
            ).all()
        )
        return items, total

    @staticmethod
    def _criteria(user_id: int, tag_id: int | None) -> list:
        criteria = [KnowledgeItem.user_id == user_id]
        if tag_id is not None:
            criteria.append(
                KnowledgeItem.id.in_(
                    select(TagLink.target_id)
                    .join(Tag, Tag.id == TagLink.tag_id)
                    .where(
                        Tag.user_id == user_id,
                        TagLink.target_type == TagTarget.KNOWLEDGE,
                        TagLink.tag_id == tag_id,
                    )
                )
            )
        return criteria

    def count_items(
        self, user_id: int, criteria: list | None = None, tag_id: int | None = None
    ) -> int:
        return (
            self.session.scalar(
                select(func.count(KnowledgeItem.id)).where(
                    *self._criteria(user_id, tag_id),
                    *(criteria or []),
                )
            )
            or 0
        )

    def titles_for(
        self, item_ids: list[int], criteria: list | None = None
    ) -> dict[int, str]:
        if not item_ids:
            return {}
        rows = self.session.execute(
            select(KnowledgeItem.id, KnowledgeItem.title).where(
                KnowledgeItem.id.in_(item_ids),
                *(criteria or []),
            )
        ).all()
        return {item_id: title for item_id, title in rows}

    def relations_for(self, item_ids: list[int]) -> list[tuple[int, int]]:
        if not item_ids:
            return []
        rows = self.session.execute(
            select(KnowledgeRelation.source_id, KnowledgeRelation.target_id)
            .where(
                or_(
                    KnowledgeRelation.source_id.in_(item_ids),
                    KnowledgeRelation.target_id.in_(item_ids),
                )
            )
            .order_by(KnowledgeRelation.id)
        ).all()
        return [(source, target) for source, target in rows]

    def relation_exists(self, first_id: int, second_id: int) -> bool:
        found = self.session.scalar(
            select(KnowledgeRelation.id).where(
                or_(
                    (KnowledgeRelation.source_id == first_id)
                    & (KnowledgeRelation.target_id == second_id),
                    (KnowledgeRelation.source_id == second_id)
                    & (KnowledgeRelation.target_id == first_id),
                )
            )
        )
        return found is not None

    def remove_relation(self, first_id: int, second_id: int) -> None:
        self.session.execute(
            delete(KnowledgeRelation).where(
                or_(
                    (KnowledgeRelation.source_id == first_id)
                    & (KnowledgeRelation.target_id == second_id),
                    (KnowledgeRelation.source_id == second_id)
                    & (KnowledgeRelation.target_id == first_id),
                )
            )
        )

    def delete_relations_for(self, item_id: int) -> None:
        self.session.execute(
            delete(KnowledgeRelation).where(
                or_(
                    KnowledgeRelation.source_id == item_id,
                    KnowledgeRelation.target_id == item_id,
                )
            )
        )

    def delete_attachments_for(self, item_id: int) -> None:
        self.session.execute(
            delete(KnowledgeAttachment).where(KnowledgeAttachment.item_id == item_id)
        )

    def goals_for(
        self, item_ids: list[int], criteria: list | None = None
    ) -> list[tuple[int, int, str]]:
        if not item_ids:
            return []
        rows = self.session.execute(
            select(KnowledgeGoalLink.item_id, Goal.id, Goal.title)
            .join(Goal, Goal.id == KnowledgeGoalLink.goal_id)
            .where(
                KnowledgeGoalLink.item_id.in_(item_ids),
                *(criteria or []),
            )
            .order_by(Goal.title, Goal.id)
        ).all()
        return [(item_id, goal_id, title) for item_id, goal_id, title in rows]

    def get_goal(
        self, user_id: int, goal_id: int, criteria: list | None = None
    ) -> Goal | None:
        return self.session.scalar(
            select(Goal).where(
                Goal.id == goal_id,
                Goal.user_id == user_id,
                *(criteria or []),
            )
        )

    def goal_link_exists(self, item_id: int, goal_id: int) -> bool:
        found = self.session.scalar(
            select(KnowledgeGoalLink.id).where(
                KnowledgeGoalLink.item_id == item_id,
                KnowledgeGoalLink.goal_id == goal_id,
            )
        )
        return found is not None

    def add_goal_link(self, item_id: int, goal_id: int) -> None:
        self.session.add(KnowledgeGoalLink(item_id=item_id, goal_id=goal_id))

    def remove_goal_link(self, item_id: int, goal_id: int) -> None:
        self.session.execute(
            delete(KnowledgeGoalLink).where(
                KnowledgeGoalLink.item_id == item_id,
                KnowledgeGoalLink.goal_id == goal_id,
            )
        )

    def delete_goal_links_for(self, item_id: int) -> None:
        self.session.execute(
            delete(KnowledgeGoalLink).where(KnowledgeGoalLink.item_id == item_id)
        )

    def attachments_meta(self, item_ids: list[int]) -> list[tuple]:
        if not item_ids:
            return []
        rows = self.session.execute(
            select(
                KnowledgeAttachment.id,
                KnowledgeAttachment.item_id,
                KnowledgeAttachment.filename,
                KnowledgeAttachment.content_type,
                KnowledgeAttachment.size_bytes,
            )
            .where(KnowledgeAttachment.item_id.in_(item_ids))
            .order_by(KnowledgeAttachment.id)
        ).all()
        return [tuple(row) for row in rows]

    def count_attachments(self, item_id: int) -> int:
        return (
            self.session.scalar(
                select(func.count(KnowledgeAttachment.id)).where(
                    KnowledgeAttachment.item_id == item_id
                )
            )
            or 0
        )

    def get_attachment(
        self, user_id: int, item_id: int, attachment_id: int
    ) -> KnowledgeAttachment | None:
        return self.session.scalar(
            select(KnowledgeAttachment)
            .join(KnowledgeItem, KnowledgeItem.id == KnowledgeAttachment.item_id)
            .where(
                KnowledgeAttachment.id == attachment_id,
                KnowledgeAttachment.item_id == item_id,
                KnowledgeItem.user_id == user_id,
            )
        )

    def graph_items(
        self,
        user_id: int,
        limit: int,
        criteria: list | None = None,
        tag_id: int | None = None,
    ) -> list[tuple[int, str, str]]:
        rows = self.session.execute(
            select(
                KnowledgeItem.id,
                KnowledgeItem.title,
                KnowledgeItem.sensitivity,
            )
            .where(
                *self._criteria(user_id, tag_id),
                *(criteria or []),
            )
            .order_by(KnowledgeItem.updated_at.desc(), KnowledgeItem.id.desc())
            .limit(limit)
        ).all()
        return [(item_id, title, sensitivity) for item_id, title, sensitivity in rows]

    def relations_between(
        self, item_ids: list[int]
    ) -> list[tuple[int, int]]:
        if len(item_ids) < 2:
            return []
        rows = self.session.execute(
            select(KnowledgeRelation.source_id, KnowledgeRelation.target_id)
            .where(
                KnowledgeRelation.source_id.in_(item_ids),
                KnowledgeRelation.target_id.in_(item_ids),
            )
            .order_by(KnowledgeRelation.id)
        ).all()
        return [(source, target) for source, target in rows]

    def add(self, row: KnowledgeItem | KnowledgeRelation | KnowledgeAttachment) -> None:
        self.session.add(row)

    def remove(self, row: KnowledgeItem | KnowledgeAttachment) -> None:
        self.session.delete(row)
