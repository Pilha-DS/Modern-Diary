from datetime import date, datetime

from sqlalchemy.orm import Session

from atena_pattern.core.access import AccessGuard, Actor
from atena_pattern.core.errors import AppError
from app.core.areas import Area
from app.models.audit import AuditArea, AuditKind
from app.models.life_link import EntityLink, LinkType
from atena_pattern.models.sensitivity import Sensitivity
from app.repositories.life_repository import LifeEntityRow, LifeRepository
from app.schemas.life import LifeEdge, LifeGraphResponse, LifeLinkRequest, LifeNode
from app.services.audit_service import AuditRef, AuditService

#: Teto por tipo: o grafo mostra o que foi mexido por último, não a vida toda.
MAX_NODES_PER_TYPE = 80
MAX_LINKS = 1000

LINK_AREA: dict[LinkType, Area] = {
    LinkType.KNOWLEDGE: Area.KNOWLEDGE,
    LinkType.GOAL: Area.GOAL,
    LinkType.NOTE: Area.NOTE,
    LinkType.ACTIVITY: Area.ACTIVITY,
    LinkType.DAY: Area.DAY,
}

AUDIT_AREA: dict[LinkType, AuditArea] = {
    LinkType.KNOWLEDGE: AuditArea.KNOWLEDGE,
    LinkType.GOAL: AuditArea.GOAL,
    LinkType.NOTE: AuditArea.NOTE,
    LinkType.ACTIVITY: AuditArea.ACTIVITY,
    LinkType.DAY: AuditArea.DAY,
}


class LifeService:
    """Grafo de vida: tudo que o usuário tocou, ligado por relação ou à mão."""

    def __init__(self, session: Session, actor: Actor) -> None:
        self.session = session
        self.actor = actor
        self.access = AccessGuard(session, actor)
        self.life = LifeRepository(session)
        self.audit = AuditService(session, actor.user_id)

    def graph(self, types: list[LinkType] | None = None) -> LifeGraphResponse:
        selected = types or list(LinkType)
        criteria: dict[LinkType, list] = {}
        for link_type in selected:
            visible = self.access.optional_visible(LINK_AREA[link_type])
            # Secret sem a área simplesmente não vê aqueles nós.
            if visible is not None:
                criteria[link_type] = visible

        nodes: dict[str, LifeEntityRow] = {}
        truncated = False
        for link_type in criteria:
            rows = self.life.entities(
                self.actor.user_id,
                [link_type],
                criteria,
                MAX_NODES_PER_TYPE + 1,
            )
            if len(rows) > MAX_NODES_PER_TYPE:
                truncated = True
                rows = rows[:MAX_NODES_PER_TYPE]
            nodes.update({row.key: row for row in rows})

        for row in list(nodes.values()):
            if row.type is LinkType.ACTIVITY and row.day is not None:
                day_key = f"{LinkType.DAY.value}:{row.day.isoformat()}"
                nodes.setdefault(
                    day_key,
                    LifeEntityRow(
                        type=LinkType.DAY,
                        ref=row.day.isoformat(),
                        title=None,
                        day=row.day,
                        sensitivity=row.sensitivity,
                        updated_at=row.updated_at,
                    ),
                )

        degrees = {key: 0 for key in nodes}
        edges: dict[tuple[str, str], LifeEdge] = {}

        def add_edge(
            first: str, second: str, kind: str, link_id: int | None = None
        ) -> None:
            if first == second or first not in nodes or second not in nodes:
                return
            pair = tuple(sorted((first, second)))
            if pair in edges:
                return
            edges[pair] = LifeEdge(
                source=pair[0], target=pair[1], kind=kind, link_id=link_id
            )
            degrees[first] = degrees.get(first, 0) + 1
            degrees[second] = degrees.get(second, 0) + 1

        knowledge_ids = _ids_of(nodes, LinkType.KNOWLEDGE)
        goal_ids = _ids_of(nodes, LinkType.GOAL)

        for source, target in self.life.relations_between(knowledge_ids):
            add_edge(
                _key(LinkType.KNOWLEDGE, source),
                _key(LinkType.KNOWLEDGE, target),
                "relation",
            )
        for item_id, goal_id in self.life.goal_links_between(
            knowledge_ids, goal_ids
        ):
            add_edge(
                _key(LinkType.KNOWLEDGE, item_id),
                _key(LinkType.GOAL, goal_id),
                "goal",
            )
        for row in nodes.values():
            if row.type is LinkType.ACTIVITY and row.day is not None:
                add_edge(
                    row.key,
                    f"{LinkType.DAY.value}:{row.day.isoformat()}",
                    "agenda",
                )

        self._add_custom_links(nodes, criteria, add_edge)

        ordered = sorted(
            nodes.values(),
            key=lambda row: (-degrees.get(row.key, 0), _sort_label(row)),
        )
        return LifeGraphResponse(
            nodes=[
                LifeNode(
                    id=row.key,
                    type=row.type,
                    ref=row.ref,
                    title=row.title,
                    day=row.day,
                    degree=degrees[row.key],
                )
                for row in ordered
            ],
            edges=list(edges.values()),
            truncated=truncated,
        )

    def link(self, payload: LifeLinkRequest) -> EntityLink:
        source = self._resolve(payload.source_type, payload.source_ref)
        target = self._resolve(payload.target_type, payload.target_ref)
        if source.key == target.key:
            raise AppError(
                code="LIFE_LINK_SELF",
                message="Um registro não pode se conectar a ele mesmo.",
                status_code=422,
            )
        self._ensure_write(source)
        self._ensure_write(target)

        first, second = _ordered(source, target)
        if self.life.link_exists(
            self.actor.user_id,
            first.type,
            first.ref,
            second.type,
            second.ref,
        ):
            raise AppError(
                code="LIFE_LINK_EXISTS",
                message="Estes registros já estão conectados.",
                status_code=409,
            )

        link = EntityLink(
            user_id=self.actor.user_id,
            source_type=first.type,
            source_ref=first.ref,
            target_type=second.type,
            target_ref=second.ref,
        )
        self.life.add(link)
        self.audit.record(
            area=AUDIT_AREA[first.type],
            kind=AuditKind.LINK,
            source=_audit_ref(first),
            target=_audit_ref(second),
        )
        self.session.commit()
        return link

    def unlink(self, payload: LifeLinkRequest) -> None:
        source = self._resolve(payload.source_type, payload.source_ref)
        target = self._resolve(payload.target_type, payload.target_ref)
        self._ensure_write(source)
        self._ensure_write(target)

        first, second = _ordered(source, target)
        removed = self.life.remove_link(
            self.actor.user_id,
            first.type,
            first.ref,
            second.type,
            second.ref,
        )
        if not removed:
            raise AppError(
                code="LIFE_LINK_NOT_FOUND",
                message="Esta conexão não existe.",
                status_code=404,
            )
        self.audit.record(
            area=AUDIT_AREA[first.type],
            kind=AuditKind.UNLINK,
            source=_audit_ref(first),
            target=_audit_ref(second),
        )
        self.session.commit()

    def _add_custom_links(
        self,
        nodes: dict[str, LifeEntityRow],
        criteria: dict[LinkType, list],
        add_edge,
    ) -> None:
        links = self.life.links(self.actor.user_id, MAX_LINKS)
        missing: dict[LinkType, set[str]] = {}
        for link in links:
            for link_type, ref in (
                (link.source_type, link.source_ref),
                (link.target_type, link.target_ref),
            ):
                key = f"{link_type.value}:{ref}"
                if key not in nodes and link_type in criteria:
                    missing.setdefault(link_type, set()).add(ref)

        for link_type, refs in missing.items():
            for row in self.life.entities_by_refs(
                self.actor.user_id,
                link_type,
                sorted(refs),
                criteria[link_type],
            ):
                nodes.setdefault(row.key, row)
            if link_type is LinkType.DAY:
                # Dia sem conteúdo ainda não tem linha: a data basta.
                for ref in refs:
                    nodes.setdefault(
                        f"{LinkType.DAY.value}:{ref}",
                        LifeEntityRow(
                            type=LinkType.DAY,
                            ref=ref,
                            title=None,
                            day=date.fromisoformat(ref),
                            sensitivity=Sensitivity.PUBLIC,
                            updated_at=datetime(1970, 1, 1),
                        ),
                    )

        for link in links:
            add_edge(
                f"{link.source_type.value}:{link.source_ref}",
                f"{link.target_type.value}:{link.target_ref}",
                "custom",
                link.id,
            )

    def _resolve(self, link_type: LinkType, ref: str) -> LifeEntityRow:
        row = self._find(link_type, ref)
        if row is None:
            raise AppError(
                code="LIFE_ENTITY_NOT_FOUND",
                message="Registro não encontrado.",
                status_code=404,
            )
        return row

    def _find(self, link_type: LinkType, ref: str) -> LifeEntityRow | None:
        criteria = self.access.optional_visible(LINK_AREA[link_type])
        if criteria is None:
            raise AppError(
                code="AREA_NOT_PERMITTED",
                message="Esta credencial não tem acesso a esta área.",
                status_code=403,
            )
        if link_type is LinkType.DAY:
            if not _is_day(ref):
                raise AppError(
                    code="LIFE_ENTITY_NOT_FOUND",
                    message="Registro não encontrado.",
                    status_code=404,
                )
            rows = self.life.entities_by_refs(
                self.actor.user_id, link_type, [ref], criteria
            )
            if rows:
                return rows[0]
            # Dia sem conteúdo ainda não tem linha: só a data identifica.
            day = date.fromisoformat(ref)
            return LifeEntityRow(
                type=link_type,
                ref=ref,
                title=None,
                day=day,
                sensitivity=Sensitivity.PUBLIC,
                updated_at=datetime(1970, 1, 1),
            )
        if not ref.isdigit():
            return None
        rows = self.life.entities_by_refs(
            self.actor.user_id, link_type, [ref], criteria
        )
        return rows[0] if rows else None

    def _ensure_write(self, row: LifeEntityRow) -> None:
        self.access.ensure_write(
            LINK_AREA[row.type],
            row.sensitivity,
            target_type=row.type.value,
            target_id=int(row.ref) if row.ref.isdigit() else None,
        )


def _ids_of(nodes: dict[str, LifeEntityRow], link_type: LinkType) -> list[int]:
    return [
        int(row.ref)
        for row in nodes.values()
        if row.type is link_type and row.ref.isdigit()
    ]


def _key(link_type: LinkType, reference: int) -> str:
    return f"{link_type.value}:{reference}"


def _sort_label(row: LifeEntityRow) -> str:
    return (row.title or row.ref).lower()


def _ordered(
    first: LifeEntityRow, second: LifeEntityRow
) -> tuple[LifeEntityRow, LifeEntityRow]:
    """Mantém o par em ordem canônica, para a ligação ser única."""
    if (first.type.value, first.ref) <= (second.type.value, second.ref):
        return first, second
    return second, first


def _audit_ref(row: LifeEntityRow) -> AuditRef:
    return AuditRef(row.type.value, row.ref, row.title or row.ref)


def _is_day(ref: str) -> bool:
    try:
        date.fromisoformat(ref)
    except ValueError:
        return False
    return True
