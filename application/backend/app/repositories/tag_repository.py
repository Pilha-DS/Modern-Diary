from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.models.goal import Goal
from app.models.knowledge import KnowledgeItem
from app.models.tag import Tag, TagLink, TagTarget


class TagRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get(self, user_id: int, tag_id: int) -> Tag | None:
        return self.session.scalar(
            select(Tag).where(Tag.id == tag_id, Tag.user_id == user_id)
        )

    def get_by_name(self, user_id: int, name: str) -> Tag | None:
        return self.session.scalar(
            select(Tag).where(
                Tag.user_id == user_id,
                func.lower(Tag.name) == name.lower(),
            )
        )

    def list_page(
        self,
        user_id: int,
        query: str | None,
        offset: int,
        limit: int,
    ) -> tuple[list[Tag], int]:
        criteria = [Tag.user_id == user_id]
        if query:
            criteria.append(Tag.name.like(f"{_escape_like(query)}%", escape="\\"))

        total = (
            self.session.scalar(select(func.count(Tag.id)).where(*criteria)) or 0
        )
        tags = list(
            self.session.scalars(
                select(Tag)
                .where(*criteria)
                .order_by(Tag.name, Tag.id)
                .offset(offset)
                .limit(limit)
            ).all()
        )
        return tags, total

    def count_tags(self, user_id: int) -> int:
        return (
            self.session.scalar(
                select(func.count(Tag.id)).where(Tag.user_id == user_id)
            )
            or 0
        )

    def by_ids(self, user_id: int, tag_ids: list[int]) -> list[Tag]:
        if not tag_ids:
            return []
        return list(
            self.session.scalars(
                select(Tag).where(
                    Tag.user_id == user_id,
                    Tag.id.in_(tag_ids),
                )
            ).all()
        )

    def usage_counts(self, tag_ids: list[int]) -> dict[int, int]:
        if not tag_ids:
            return {}
        rows = self.session.execute(
            select(TagLink.tag_id, func.count(TagLink.id))
            .where(TagLink.tag_id.in_(tag_ids))
            .group_by(TagLink.tag_id)
        ).all()
        return {tag_id: int(total) for tag_id, total in rows}

    def usage_page(
        self,
        tag_id: int,
        offset: int,
        limit: int,
    ) -> tuple[list[TagLink], int]:
        total = (
            self.session.scalar(
                select(func.count(TagLink.id)).where(TagLink.tag_id == tag_id)
            )
            or 0
        )
        links = list(
            self.session.scalars(
                select(TagLink)
                .where(TagLink.tag_id == tag_id)
                .order_by(TagLink.id.desc())
                .offset(offset)
                .limit(limit)
            ).all()
        )
        return links, total

    def knowledge_titles(self, item_ids: list[int]) -> dict[int, str]:
        if not item_ids:
            return {}
        rows = self.session.execute(
            select(KnowledgeItem.id, KnowledgeItem.title).where(
                KnowledgeItem.id.in_(item_ids)
            )
        ).all()
        return {item_id: title for item_id, title in rows}

    def goal_titles(self, goal_ids: list[int]) -> dict[int, str]:
        if not goal_ids:
            return {}
        rows = self.session.execute(
            select(Goal.id, Goal.title).where(Goal.id.in_(goal_ids))
        ).all()
        return {goal_id: title for goal_id, title in rows}

    def tags_for_targets(
        self,
        user_id: int,
        target_type: TagTarget,
        target_ids: list[int],
    ) -> dict[int, list[Tag]]:
        grouped: dict[int, list[Tag]] = {target_id: [] for target_id in target_ids}
        if not target_ids:
            return grouped
        rows = self.session.execute(
            select(TagLink.target_id, Tag)
            .join(Tag, Tag.id == TagLink.tag_id)
            .where(
                Tag.user_id == user_id,
                TagLink.target_type == target_type,
                TagLink.target_id.in_(target_ids),
            )
            .order_by(Tag.name, Tag.id)
        ).all()
        for target_id, tag in rows:
            grouped[target_id].append(tag)
        return grouped

    def links_for_days(
        self,
        user_id: int,
        first_ordinal: int,
        last_ordinal: int,
    ) -> list[tuple[int, Tag]]:
        rows = self.session.execute(
            select(TagLink.target_id, Tag)
            .join(Tag, Tag.id == TagLink.tag_id)
            .where(
                Tag.user_id == user_id,
                TagLink.target_type == TagTarget.AGENDA_DAY,
                TagLink.target_id >= first_ordinal,
                TagLink.target_id <= last_ordinal,
            )
            .order_by(TagLink.target_id, Tag.name, Tag.id)
        ).all()
        return [(target_id, tag) for target_id, tag in rows]

    def tag_ids_for_target(
        self,
        target_type: TagTarget,
        target_id: int,
    ) -> list[int]:
        return list(
            self.session.scalars(
                select(TagLink.tag_id).where(
                    TagLink.target_type == target_type,
                    TagLink.target_id == target_id,
                )
            ).all()
        )

    def replace_links(
        self,
        target_type: TagTarget,
        target_id: int,
        tag_ids: list[int],
    ) -> None:
        self.remove_links_for_target(target_type, target_id)
        for tag_id in tag_ids:
            self.session.add(
                TagLink(
                    tag_id=tag_id,
                    target_type=target_type,
                    target_id=target_id,
                )
            )

    def remove_links_for_target(
        self,
        target_type: TagTarget,
        target_id: int,
    ) -> None:
        self.session.execute(
            delete(TagLink).where(
                TagLink.target_type == target_type,
                TagLink.target_id == target_id,
            )
        )

    def remove_links_for_tag(self, tag_id: int) -> None:
        self.session.execute(delete(TagLink).where(TagLink.tag_id == tag_id))

    def add(self, tag: Tag) -> None:
        self.session.add(tag)

    def remove(self, tag: Tag) -> None:
        self.session.delete(tag)


def _escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
