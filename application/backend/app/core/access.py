from dataclasses import dataclass
from typing import NoReturn

from sqlalchemy.orm import InstrumentedAttribute, Session

from app.core.errors import AppError
from app.core.request_context import current_request_id
from app.models.agenda import AgendaActivity, AgendaDay
from app.models.api_secret import (
    ApiSecret,
    AuditAction,
    AuditResult,
    SecretAreaPermission,
    SecretAuditLog,
)
from app.models.area import Area
from app.models.goal import Goal
from app.models.knowledge import KnowledgeItem
from app.models.note import Note
from app.models.sensitivity import Sensitivity

#: Coluna de sensibilidade de cada área. Área nova entra aqui e no enum `Area`.
AREA_SENSITIVITY: dict[Area, InstrumentedAttribute] = {
    Area.KNOWLEDGE: KnowledgeItem.sensitivity,
    Area.NOTE: Note.sensitivity,
    Area.GOAL: Goal.sensitivity,
    Area.DAY: AgendaDay.sensitivity,
    Area.ACTIVITY: AgendaActivity.sensitivity,
}


@dataclass(frozen=True)
class Actor:
    """Quem age na requisição: o dono (sessão) ou uma secret dele.

    A sessão enxerga tudo do próprio usuário. A secret é limitada pelas
    permissões da área e pelo nível de sensibilidade de cada registro.
    """

    user_id: int
    secret: ApiSecret | None = None

    @property
    def is_session(self) -> bool:
        return self.secret is None


class AccessGuard:
    """Único ponto de decisão de acesso do sistema.

    Toda leitura filtra por nível no próprio banco (`criteria`), e toda
    criação, alteração ou exclusão passa por `ensure_*`. A decisão negada é
    registrada na auditoria e responde 403; um registro acima do limite de
    leitura simplesmente não é encontrado.
    """

    def __init__(self, session: Session, actor: Actor) -> None:
        self.session = session
        self.actor = actor

    # -- leitura ---------------------------------------------------------

    def optional_visible(self, area: Area) -> list | None:
        """Critérios de nível da área; `None` quando a secret não tem a área."""
        if self.actor.secret is None:
            return []
        permission = self.actor.secret.permission_for(area)
        if permission is None:
            return None
        return self._level_criteria(area, permission.read_level)

    def visible(self, area: Area) -> list:
        """Critérios de nível da área; 403 quando a secret não tem a área."""
        criteria = self.optional_visible(area)
        if criteria is None:
            self._deny(
                code="AREA_NOT_PERMITTED",
                message="Esta credencial não tem acesso a esta área.",
                area=area,
                action=AuditAction.READ,
            )
        return criteria

    def optional_visible_on(
        self, area: Area, column: InstrumentedAttribute
    ) -> list | None:
        """Como [optional_visible], filtrando pela coluna de nível indicada.

        A área pode ter mais de uma tabela (o dia e as notas dele): as duas
        usam a permissão da área, cada uma com a própria coluna.
        """
        if self.actor.secret is None:
            return []
        permission = self.actor.secret.permission_for(area)
        if permission is None:
            return None
        if permission.read_level is Sensitivity.ALL:
            return []
        return [column <= permission.read_level]

    def visible_on(self, area: Area, column: InstrumentedAttribute) -> list:
        criteria = self.optional_visible_on(area, column)
        if criteria is None:
            self._deny(
                code="AREA_NOT_PERMITTED",
                message="Esta credencial não tem acesso a esta área.",
                area=area,
                action=AuditAction.READ,
            )
        return criteria

    def read_level(self, area: Area) -> Sensitivity:
        """Nível máximo lido na área; 403 quando a secret não tem a área."""
        if self.actor.secret is None:
            return Sensitivity.ALL
        permission = self.actor.secret.permission_for(area)
        if permission is None:
            self._deny(
                code="AREA_NOT_PERMITTED",
                message="Esta credencial não tem acesso a esta área.",
                area=area,
                action=AuditAction.READ,
            )
        return permission.read_level

    # -- criação e escrita ----------------------------------------------

    def ensure_create(self, area: Area, *, target_type: str) -> None:
        """Criar é independente do nível: a secret cria em qualquer nível."""
        if self.actor.secret is None:
            return
        permission = self._permission_or_deny(area, AuditAction.CREATE, target_type)
        if not permission.can_create:
            self._deny(
                code="CREATE_NOT_PERMITTED",
                message="Esta credencial não pode criar registros nesta área.",
                area=area,
                action=AuditAction.CREATE,
                target_type=target_type,
            )

    def record_created(self, area: Area, target_type: str, target_id: int) -> None:
        """Audita a criação já concluída, com o identificador do registro."""
        self._record(
            area=area,
            action=AuditAction.CREATE,
            result=AuditResult.ALLOWED,
            target_type=target_type,
            target_id=target_id,
        )

    def ensure_write(
        self,
        area: Area,
        level: Sensitivity,
        *,
        target_type: str,
        target_id: int | None,
        action: AuditAction = AuditAction.UPDATE,
    ) -> None:
        """Alterar exige escrita habilitada e registro dentro do nível lido."""
        if self.actor.secret is None:
            return
        permission = self._permission_or_deny(area, action, target_type, target_id)
        if not permission.can_write:
            self._deny(
                code="WRITE_NOT_PERMITTED",
                message="Esta credencial não pode alterar registros nesta área.",
                area=area,
                action=action,
                target_type=target_type,
                target_id=target_id,
            )
        if level > permission.read_level:
            self._deny(
                code="WRITE_NOT_PERMITTED",
                message="Esta credencial não pode alterar este registro.",
                area=area,
                action=action,
                target_type=target_type,
                target_id=target_id,
            )
        self._record(
            area=area,
            action=action,
            result=AuditResult.ALLOWED,
            target_type=target_type,
            target_id=target_id,
        )

    def ensure_new_level(self, area: Area, level: Sensitivity) -> None:
        """A secret não reclassifica um registro para fora do que ela lê.

        A criação aceita qualquer nível; a alteração não, para que uma escrita
        não esconda (nem exponha) um registro fora do limite da credencial.
        """
        if self.actor.secret is None:
            return
        permission = self.actor.secret.permission_for(area)
        if permission is None or level > permission.read_level:
            self._deny(
                code="SENSITIVITY_NOT_ALLOWED",
                message=(
                    "A credencial não pode classificar um registro acima do "
                    "próprio nível de leitura."
                ),
                area=area,
                action=AuditAction.UPDATE,
            )

    # -- interno ---------------------------------------------------------

    @staticmethod
    def _level_criteria(area: Area, level: Sensitivity) -> list:
        if level is Sensitivity.ALL:
            return []
        return [AREA_SENSITIVITY[area] <= level]

    def _permission_or_deny(
        self,
        area: Area,
        action: AuditAction,
        target_type: str | None,
        target_id: int | None = None,
    ) -> SecretAreaPermission:
        permission = (
            self.actor.secret.permission_for(area) if self.actor.secret else None
        )
        if permission is None:
            self._deny(
                code="AREA_NOT_PERMITTED",
                message="Esta credencial não tem acesso a esta área.",
                area=area,
                action=action,
                target_type=target_type,
                target_id=target_id,
            )
        return permission

    def _deny(
        self,
        *,
        code: str,
        message: str,
        area: Area,
        action: AuditAction,
        target_type: str | None = None,
        target_id: int | None = None,
    ) -> NoReturn:
        self._record(
            area=area,
            action=action,
            result=AuditResult.DENIED,
            target_type=target_type,
            target_id=target_id,
        )
        # A recusa precisa sobreviver ao rollback da resposta de erro. Neste
        # ponto nenhuma alteração da operação foi feita, então não há o que
        # perder no commit.
        self.session.commit()
        raise AppError(code=code, message=message, status_code=403)

    def _record(
        self,
        *,
        area: Area,
        action: AuditAction,
        result: AuditResult,
        target_type: str | None,
        target_id: int | None,
    ) -> None:
        secret = self.actor.secret
        if secret is None:
            return
        self.session.add(
            SecretAuditLog(
                user_id=self.actor.user_id,
                secret_id=secret.id,
                area=area,
                action=action,
                result=result,
                target_type=target_type,
                target_id=target_id,
                request_id=current_request_id() or None,
            )
        )
