import re
from dataclasses import dataclass
from pathlib import PurePosixPath, PureWindowsPath

from sqlalchemy.orm import Session

from atena_pattern.core.access import AccessGuard, Actor
from atena_pattern.core.errors import AppError
from atena_pattern.core.security import create_attachment_token, decode_attachment_token
from atena_pattern.models.api_secret import AuditAction
from app.core.areas import Area
from app.models.audit import AuditArea, AuditKind
from app.models.knowledge import (
    KnowledgeAttachment,
    KnowledgeItem,
    KnowledgeObservation,
    KnowledgeRelation,
)
from app.models.life_link import LinkType
from atena_pattern.models.sensitivity import Sensitivity
from app.models.tag import TagTarget
from app.repositories.knowledge_repository import KnowledgeRepository
from app.repositories.life_repository import LifeRepository
from app.schemas.knowledge import (
    GRAPH_MAX_NODES,
    MAX_ATTACHMENT_BYTES,
    MAX_ATTACHMENTS_PER_ITEM,
    MAX_ITEMS_PER_USER,
    MAX_OBSERVATIONS_PER_ITEM,
    GraphEdge,
    GraphNode,
    KnowledgeGraphResponse,
    KnowledgeLink,
    stored_links,
)
from app.schemas.tag import TagSummary
from app.services.audit_service import AuditRef, AuditService
from app.services.tag_service import TagService


@dataclass
class KnowledgeDetails:
    """Dados ligados aos itens de uma página, carregados em lote."""

    relations: dict[int, list[tuple[int, str]]]
    attachments: dict[int, list[tuple]]
    goals: dict[int, list[tuple[int, str]]]
    tags: dict[int, list[TagSummary]]
    observations: dict[int, list[KnowledgeObservation]]


class KnowledgeService:
    def __init__(self, session: Session, actor: Actor) -> None:
        self.session = session
        self.actor = actor
        self.access = AccessGuard(session, actor)
        self.knowledge = KnowledgeRepository(session)
        self.tags = TagService(session)
        self.audit = AuditService(session, actor.user_id)

    def list_items(
        self, *, offset: int, limit: int, tag_id: int | None = None
    ) -> tuple[list[KnowledgeItem], int]:
        return self.knowledge.list_page(
            self.actor.user_id,
            offset,
            limit,
            tag_id,
            self.access.visible(Area.KNOWLEDGE),
        )

    def describe(self, items: list[KnowledgeItem]) -> KnowledgeDetails:
        """Carrega conexões, anexos, metas e tags de uma página."""
        item_ids = [item.id for item in items]
        pairs = self.knowledge.relations_for(item_ids)

        other_ids = {
            target if source in item_ids else source for source, target in pairs
        }
        visible_titles = self.knowledge.titles_for(
            sorted(other_ids),
            self.access.visible(Area.KNOWLEDGE),
        )

        relations: dict[int, list[tuple[int, str]]] = {item_id: [] for item_id in item_ids}
        for source, target in pairs:
            if source in relations and target in visible_titles:
                relations[source].append((target, visible_titles[target]))
            if target in relations and source in visible_titles:
                relations[target].append((source, visible_titles[source]))

        attachments: dict[int, list[tuple]] = {item_id: [] for item_id in item_ids}
        for row in self.knowledge.attachments_meta(item_ids):
            attachments[row[1]].append(row)

        goals: dict[int, list[tuple[int, str]]] = {item_id: [] for item_id in item_ids}
        goal_criteria = self.access.optional_visible(Area.GOAL)
        if goal_criteria is not None:
            for item_id, goal_id, goal_title in self.knowledge.goals_for(
                item_ids, goal_criteria
            ):
                goals[item_id].append((goal_id, goal_title))

        return KnowledgeDetails(
            relations=relations,
            attachments=attachments,
            goals=goals,
            tags=self.tags.tags_for_targets(
                self.actor.user_id,
                TagTarget.KNOWLEDGE,
                item_ids,
            ),
            observations=self._observations_of(item_ids),
        )

    def _observations_of(
        self, item_ids: list[int]
    ) -> dict[int, list[KnowledgeObservation]]:
        observations: dict[int, list[KnowledgeObservation]] = {
            item_id: [] for item_id in item_ids
        }
        for observation in self.knowledge.observations_for(item_ids):
            observations[observation.item_id].append(observation)
        return observations

    def get_item(self, item_id: int) -> KnowledgeItem:
        return self._get_item_or_fail(item_id)

    def create_item(
        self,
        *,
        title: str,
        content: str | None,
        links: list[KnowledgeLink],
        sensitivity: Sensitivity,
        tag_ids: list[int] | None = None,
    ) -> KnowledgeItem:
        self.access.ensure_create(Area.KNOWLEDGE, target_type="knowledge")
        if self.knowledge.count_items(self.actor.user_id) >= MAX_ITEMS_PER_USER:
            raise AppError(
                code="KNOWLEDGE_LIMIT",
                message="Você já atingiu o limite de conhecimentos.",
                status_code=409,
            )

        item = KnowledgeItem(
            user_id=self.actor.user_id,
            title=title,
            content=content,
            links=stored_links(links) or None,
            sensitivity=sensitivity,
        )
        self.knowledge.add(item)
        self.session.flush()
        self.access.record_created(Area.KNOWLEDGE, "knowledge", item.id)
        self.audit.record(
            area=AuditArea.KNOWLEDGE,
            kind=AuditKind.CREATE,
            source=AuditRef("knowledge", str(item.id), item.title),
        )
        if tag_ids:
            self.tags.set_tags(
                self.actor.user_id, TagTarget.KNOWLEDGE, item.id, tag_ids
            )
        self.session.commit()
        return item

    def update_item(
        self,
        item_id: int,
        *,
        title: str | None = None,
        content: str | None = None,
        change_content: bool = False,
        links: list[KnowledgeLink] | None = None,
        change_links: bool = False,
        sensitivity: Sensitivity | None = None,
        tag_ids: list[int] | None = None,
        change_tags: bool = False,
    ) -> KnowledgeItem:
        item = self._get_item_or_fail(item_id)
        self.access.ensure_write(
            Area.KNOWLEDGE,
            item.sensitivity,
            target_type="knowledge",
            target_id=item.id,
        )

        if title is not None:
            item.title = title
        if change_content:
            item.content = content
        if change_links:
            item.links = stored_links(links) or None
        if sensitivity is not None:
            self.access.ensure_new_level(Area.KNOWLEDGE, sensitivity)
            item.sensitivity = sensitivity
        if change_tags:
            self.tags.set_tags(
                self.actor.user_id,
                TagTarget.KNOWLEDGE,
                item.id,
                tag_ids or [],
            )

        self.audit.record(
            area=AuditArea.KNOWLEDGE,
            kind=AuditKind.UPDATE,
            source=AuditRef("knowledge", str(item.id), item.title),
        )
        self.session.commit()
        return item

    def delete_item(self, item_id: int) -> None:
        item = self._get_item_or_fail(item_id)
        self.access.ensure_write(
            Area.KNOWLEDGE,
            item.sensitivity,
            target_type="knowledge",
            target_id=item.id,
            action=AuditAction.DELETE,
        )
        self.knowledge.delete_relations_for(item_id)
        self.knowledge.delete_attachments_for(item_id)
        self.knowledge.delete_goal_links_for(item_id)
        self.knowledge.delete_observations_for(item_id)
        LifeRepository(self.session).remove_links_for(
            self.actor.user_id, LinkType.KNOWLEDGE, str(item_id)
        )
        self.tags.remove_target_links(TagTarget.KNOWLEDGE, item_id)
        self.audit.record(
            area=AuditArea.KNOWLEDGE,
            kind=AuditKind.DELETE,
            source=AuditRef("knowledge", str(item.id), item.title),
        )
        self.knowledge.remove(item)
        self.session.commit()

    def add_relation(self, item_id: int, target_id: int) -> tuple[int, int]:
        if item_id == target_id:
            raise AppError(
                code="KNOWLEDGE_SELF_LINK",
                message="Um conhecimento não pode se conectar a ele mesmo.",
                status_code=422,
            )

        item = self._get_item_or_fail(item_id)
        target = self._get_item_or_fail(target_id)
        for linked in (item, target):
            self.access.ensure_write(
                Area.KNOWLEDGE,
                linked.sensitivity,
                target_type="knowledge",
                target_id=linked.id,
            )

        if self.knowledge.relation_exists(item_id, target_id):
            raise AppError(
                code="KNOWLEDGE_RELATION_EXISTS",
                message="Estes conhecimentos já estão conectados.",
                status_code=409,
            )

        self.knowledge.add(KnowledgeRelation(source_id=item_id, target_id=target_id))
        self.audit.record(
            area=AuditArea.KNOWLEDGE,
            kind=AuditKind.LINK,
            source=AuditRef("knowledge", str(item.id), item.title),
            target=AuditRef("knowledge", str(target.id), target.title),
        )
        self.session.commit()
        return item_id, target_id

    def remove_relation(self, item_id: int, target_id: int) -> None:
        item = self._get_item_or_fail(item_id)
        target = self._get_item_or_fail(target_id)
        for linked in (item, target):
            self.access.ensure_write(
                Area.KNOWLEDGE,
                linked.sensitivity,
                target_type="knowledge",
                target_id=linked.id,
            )
        self.knowledge.remove_relation(item_id, target_id)
        self.audit.record(
            area=AuditArea.KNOWLEDGE,
            kind=AuditKind.UNLINK,
            source=AuditRef("knowledge", str(item.id), item.title),
            target=AuditRef("knowledge", str(target.id), target.title),
        )
        self.session.commit()

    def add_goal(self, item_id: int, goal_id: int) -> tuple[int, int]:
        item = self._get_item_or_fail(item_id)
        self.access.ensure_write(
            Area.KNOWLEDGE,
            item.sensitivity,
            target_type="knowledge",
            target_id=item.id,
        )
        goal = self._get_goal_or_none(goal_id)
        if goal is None:
            raise AppError(
                code="GOAL_NOT_FOUND",
                message="Meta não encontrada.",
                status_code=404,
            )
        if self.knowledge.goal_link_exists(item_id, goal_id):
            raise AppError(
                code="KNOWLEDGE_GOAL_EXISTS",
                message="Esta meta já está ligada a este conhecimento.",
                status_code=409,
            )

        self.knowledge.add_goal_link(item_id, goal_id)
        self.audit.record(
            area=AuditArea.KNOWLEDGE,
            kind=AuditKind.LINK,
            source=AuditRef("knowledge", str(item.id), item.title),
            target=AuditRef("goal", str(goal.id), goal.title),
        )
        self.session.commit()
        return item_id, goal_id

    def remove_goal(self, item_id: int, goal_id: int) -> None:
        item = self._get_item_or_fail(item_id)
        self.access.ensure_write(
            Area.KNOWLEDGE,
            item.sensitivity,
            target_type="knowledge",
            target_id=item.id,
        )
        goal = self._get_goal_or_none(goal_id)
        if goal is None:
            raise AppError(
                code="GOAL_NOT_FOUND",
                message="Meta não encontrada.",
                status_code=404,
            )
        self.knowledge.remove_goal_link(item_id, goal_id)
        self.audit.record(
            area=AuditArea.KNOWLEDGE,
            kind=AuditKind.UNLINK,
            source=AuditRef("knowledge", str(item.id), item.title),
            target=AuditRef("goal", str(goal.id), goal.title),
        )
        self.session.commit()

    def add_attachment(
        self,
        item_id: int,
        *,
        filename: str,
        content_type: str,
        content: bytes,
    ) -> KnowledgeAttachment:
        item = self._get_item_or_fail(item_id)
        self.access.ensure_write(
            Area.KNOWLEDGE,
            item.sensitivity,
            target_type="knowledge",
            target_id=item.id,
        )

        if not content:
            raise AppError(
                code="KNOWLEDGE_ATTACHMENT_EMPTY",
                message="O arquivo está vazio.",
                status_code=422,
            )
        if len(content) > MAX_ATTACHMENT_BYTES:
            raise AppError(
                code="KNOWLEDGE_ATTACHMENT_TOO_LARGE",
                message="O arquivo passa do limite de 5 MB.",
                status_code=413,
            )
        if self.knowledge.count_attachments(item_id) >= MAX_ATTACHMENTS_PER_ITEM:
            raise AppError(
                code="KNOWLEDGE_ATTACHMENT_LIMIT",
                message="Este conhecimento já atingiu o limite de anexos.",
                status_code=409,
            )

        attachment = KnowledgeAttachment(
            item_id=item_id,
            filename=_clean_filename(filename),
            content_type=(content_type or "application/octet-stream")[:120],
            size_bytes=len(content),
            content=content,
        )
        self.knowledge.add(attachment)
        self.session.commit()
        return attachment

    def delete_attachment(self, item_id: int, attachment_id: int) -> None:
        attachment = self.knowledge.get_attachment(
            self.actor.user_id, item_id, attachment_id
        )
        if attachment is None:
            raise AppError(
                code="KNOWLEDGE_ATTACHMENT_NOT_FOUND",
                message="Anexo não encontrado.",
                status_code=404,
            )
        item = self._get_item_or_fail(item_id)
        self.access.ensure_write(
            Area.KNOWLEDGE,
            item.sensitivity,
            target_type="knowledge",
            target_id=item.id,
            action=AuditAction.DELETE,
        )
        self.knowledge.remove(attachment)
        self.session.commit()

    def add_observation(self, item_id: int, text: str) -> KnowledgeObservation:
        item = self._get_item_or_fail(item_id)
        self.access.ensure_write(
            Area.KNOWLEDGE,
            item.sensitivity,
            target_type="knowledge",
            target_id=item.id,
        )
        if (
            self.knowledge.count_observations(item_id)
            >= MAX_OBSERVATIONS_PER_ITEM
        ):
            raise AppError(
                code="KNOWLEDGE_OBSERVATION_LIMIT",
                message="Este conhecimento já atingiu o limite de observações.",
                status_code=409,
            )

        observation = KnowledgeObservation(item_id=item_id, text=text)
        self.knowledge.add(observation)
        self.audit.record(
            area=AuditArea.KNOWLEDGE,
            kind=AuditKind.UPDATE,
            source=AuditRef("knowledge", str(item.id), item.title),
        )
        self.session.commit()
        return observation

    def delete_observation(self, item_id: int, observation_id: int) -> None:
        item = self._get_item_or_fail(item_id)
        self.access.ensure_write(
            Area.KNOWLEDGE,
            item.sensitivity,
            target_type="knowledge",
            target_id=item.id,
            action=AuditAction.DELETE,
        )
        observation = self.knowledge.get_observation(
            self.actor.user_id, item_id, observation_id
        )
        if observation is None:
            raise AppError(
                code="KNOWLEDGE_OBSERVATION_NOT_FOUND",
                message="Observação não encontrada.",
                status_code=404,
            )
        self.knowledge.remove(observation)
        self.audit.record(
            area=AuditArea.KNOWLEDGE,
            kind=AuditKind.UPDATE,
            source=AuditRef("knowledge", str(item.id), item.title),
        )
        self.session.commit()

    def download_path(self, item_id: int, attachment_id: int) -> str:
        token = create_attachment_token(self.actor.user_id, attachment_id)
        return (
            f"/api/v1/knowledge/{item_id}/attachments/{attachment_id}/download"
            f"?token={token}"
        )

    def graph(self, tag_id: int | None = None) -> KnowledgeGraphResponse:
        criteria = self.access.visible(Area.KNOWLEDGE)
        rows = self.knowledge.graph_items(
            self.actor.user_id, GRAPH_MAX_NODES, criteria, tag_id
        )
        node_ids = [item_id for item_id, _, _ in rows]
        edges = self.knowledge.relations_between(node_ids)

        degrees: dict[int, int] = {item_id: 0 for item_id in node_ids}
        for source, target in edges:
            degrees[source] = degrees.get(source, 0) + 1
            degrees[target] = degrees.get(target, 0) + 1

        tags = self.tags.tags_for_targets(
            self.actor.user_id,
            TagTarget.KNOWLEDGE,
            node_ids,
        )

        return KnowledgeGraphResponse(
            nodes=[
                GraphNode(
                    id=item_id,
                    title=title,
                    degree=degrees.get(item_id, 0),
                    sensitivity=sensitivity,
                    tags=tags.get(item_id, []),
                )
                for item_id, title, sensitivity in rows
            ],
            edges=[GraphEdge(source=source, target=target) for source, target in edges],
        )

    def count_items(
        self, tag_id: int | None = None
    ) -> int:
        return self.knowledge.count_items(
            self.actor.user_id,
            self.access.visible(Area.KNOWLEDGE),
            tag_id,
        )

    def _get_goal_or_none(self, goal_id: int):
        goal_criteria = self.access.optional_visible(Area.GOAL)
        if goal_criteria is None:
            return None
        return self.knowledge.get_goal(
            self.actor.user_id, goal_id, goal_criteria
        )

    def _get_item_or_fail(self, item_id: int) -> KnowledgeItem:
        item = self.knowledge.get(
            self.actor.user_id,
            item_id,
            self.access.visible(Area.KNOWLEDGE),
        )
        if item is None:
            raise AppError(
                code="KNOWLEDGE_NOT_FOUND",
                message="Conhecimento não encontrado.",
                status_code=404,
            )
        return item


def _clean_filename(filename: str) -> str:
    base = PureWindowsPath(PurePosixPath(filename or "").name).name
    base = re.sub(r"[\x00-\x1f\x7f]", "", base).strip()
    return base[:255] or "anexo"


def find_attachment_for_download(
    session: Session,
    token: str,
    item_id: int,
    attachment_id: int,
) -> KnowledgeAttachment:
    """Resolve o anexo pelo token temporário, sem exigir sessão na requisição."""
    user_id, token_attachment_id = decode_attachment_token(token)
    if token_attachment_id != attachment_id:
        raise AppError(
            code="INVALID_TOKEN",
            message="Link de anexo inválido.",
            status_code=401,
        )

    attachment = KnowledgeRepository(session).get_attachment(
        user_id, item_id, attachment_id
    )
    if attachment is None:
        raise AppError(
            code="KNOWLEDGE_ATTACHMENT_NOT_FOUND",
            message="Anexo não encontrado.",
            status_code=404,
        )
    return attachment
