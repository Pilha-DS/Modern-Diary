from datetime import date

from sqlalchemy.orm import Session

from atena_pattern.core.errors import AppError
from app.models.audit import AuditArea, AuditKind
from app.models.tag import Tag, TagTarget
from app.repositories.tag_repository import TagRepository
from app.schemas.tag import (
    MAX_TAGS_PER_USER,
    TagSummary,
    TagUsageResponse,
    tag_summary,
)
from app.services.audit_service import AuditRef, AuditService


class TagService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.tags = TagRepository(session)

    def list_page(
        self,
        user_id: int,
        *,
        query: str | None,
        offset: int,
        limit: int,
    ) -> tuple[list[Tag], dict[int, int], int]:
        tags, total = self.tags.list_page(user_id, query, offset, limit)
        counts = self.tags.usage_counts([tag.id for tag in tags])
        return tags, counts, total

    def create_tag(
        self,
        user_id: int,
        *,
        name: str,
        color: str,
        description: str | None,
    ) -> Tag:
        if self.tags.count_tags(user_id) >= MAX_TAGS_PER_USER:
            raise AppError(
                code="TAG_LIMIT",
                message="Você já atingiu o limite de tags.",
                status_code=409,
            )
        self._ensure_name_is_free(user_id, name)

        tag = Tag(user_id=user_id, name=name, color=color, description=description)
        self.tags.add(tag)
        self.session.flush()
        AuditService(self.session, user_id).record(
            area=AuditArea.TAG,
            kind=AuditKind.CREATE,
            source=AuditRef("tag", str(tag.id), tag.name),
        )
        self.session.commit()
        return tag

    def update_tag(
        self,
        user_id: int,
        tag_id: int,
        *,
        name: str | None = None,
        color: str | None = None,
        description: str | None = None,
        change_description: bool = False,
    ) -> Tag:
        tag = self._get_tag_or_fail(user_id, tag_id)

        if name is not None and name.lower() != tag.name.lower():
            self._ensure_name_is_free(user_id, name)
            tag.name = name
        if color is not None:
            tag.color = color
        if change_description:
            tag.description = description

        AuditService(self.session, user_id).record(
            area=AuditArea.TAG,
            kind=AuditKind.UPDATE,
            source=AuditRef("tag", str(tag.id), tag.name),
        )
        self.session.commit()
        return tag

    def delete_tag(self, user_id: int, tag_id: int) -> None:
        tag = self._get_tag_or_fail(user_id, tag_id)
        self.tags.remove_links_for_tag(tag.id)
        AuditService(self.session, user_id).record(
            area=AuditArea.TAG,
            kind=AuditKind.DELETE,
            source=AuditRef("tag", str(tag.id), tag.name),
        )
        self.tags.remove(tag)
        self.session.commit()

    def usage_count(self, tag_id: int) -> int:
        return self.tags.usage_counts([tag_id]).get(tag_id, 0)

    def usages(
        self,
        user_id: int,
        tag_id: int,
        *,
        offset: int,
        limit: int,
    ) -> tuple[list[TagUsageResponse], int]:
        self._get_tag_or_fail(user_id, tag_id)
        links, total = self.tags.usage_page(tag_id, offset, limit)

        knowledge_ids = [
            link.target_id
            for link in links
            if link.target_type is TagTarget.KNOWLEDGE
        ]
        goal_ids = [
            link.target_id for link in links if link.target_type is TagTarget.GOAL
        ]
        knowledge_titles = self.tags.knowledge_titles(knowledge_ids)
        goal_titles = self.tags.goal_titles(goal_ids)

        usages: list[TagUsageResponse] = []
        for link in links:
            if link.target_type is TagTarget.KNOWLEDGE:
                usages.append(
                    TagUsageResponse(
                        target_type=link.target_type,
                        target_id=link.target_id,
                        title=knowledge_titles.get(link.target_id),
                        day=None,
                    )
                )
            elif link.target_type is TagTarget.GOAL:
                usages.append(
                    TagUsageResponse(
                        target_type=link.target_type,
                        target_id=link.target_id,
                        title=goal_titles.get(link.target_id),
                        day=None,
                    )
                )
            else:
                usages.append(
                    TagUsageResponse(
                        target_type=link.target_type,
                        target_id=link.target_id,
                        title=None,
                        day=_day_of(link.target_id),
                    )
                )
        return usages, total

    def tags_for_targets(
        self,
        user_id: int,
        target_type: TagTarget,
        target_ids: list[int],
    ) -> dict[int, list[TagSummary]]:
        grouped = self.tags.tags_for_targets(user_id, target_type, target_ids)
        return {
            target_id: [tag_summary(tag) for tag in tags]
            for target_id, tags in grouped.items()
        }

    def set_tags(
        self,
        user_id: int,
        target_type: TagTarget,
        target_id: int,
        tag_ids: list[int],
    ) -> list[TagSummary]:
        """Substitui as tags do alvo. Não faz commit: quem chama decide."""
        unique_ids = list(dict.fromkeys(tag_ids))
        found = self.tags.by_ids(user_id, unique_ids)
        if len(found) != len(unique_ids):
            raise AppError(
                code="TAG_NOT_FOUND",
                message="Uma das tags informadas não existe.",
                status_code=404,
            )

        ordered = {tag.id: tag for tag in found}
        self.tags.replace_links(
            target_type,
            target_id,
            [tag_id for tag_id in unique_ids if tag_id in ordered],
        )
        return [tag_summary(ordered[tag_id]) for tag_id in unique_ids]

    def remove_target_links(self, target_type: TagTarget, target_id: int) -> None:
        """Limpa as ligações do alvo. Não faz commit."""
        self.tags.remove_links_for_target(target_type, target_id)

    def day_tags(
        self,
        user_id: int,
        first: date,
        last: date,
    ) -> dict[date, list[TagSummary]]:
        rows = self.tags.links_for_days(
            user_id,
            first.toordinal(),
            last.toordinal(),
        )
        grouped: dict[date, list[TagSummary]] = {}
        for ordinal, tag in rows:
            day = _day_of(ordinal)
            if day is None:
                continue
            grouped.setdefault(day, []).append(tag_summary(tag))
        return grouped

    def set_day_tags(
        self,
        user_id: int,
        day: date,
        tag_ids: list[int],
    ) -> list[TagSummary]:
        return self.set_tags(user_id, TagTarget.AGENDA_DAY, day.toordinal(), tag_ids)

    def _ensure_name_is_free(self, user_id: int, name: str) -> None:
        if self.tags.get_by_name(user_id, name) is not None:
            raise AppError(
                code="TAG_EXISTS",
                message="Já existe uma tag com esse nome.",
                status_code=409,
            )

    def _get_tag_or_fail(self, user_id: int, tag_id: int) -> Tag:
        tag = self.tags.get(user_id, tag_id)
        if tag is None:
            raise AppError(
                code="TAG_NOT_FOUND",
                message="Tag não encontrada.",
                status_code=404,
            )
        return tag


def _day_of(ordinal: int) -> date | None:
    try:
        return date.fromordinal(ordinal)
    except ValueError:
        return None
