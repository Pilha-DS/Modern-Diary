from datetime import date, time

from sqlalchemy.orm import Session

from app.core.access import AccessGuard, Actor
from app.core.errors import AppError
from app.models.agenda import AgendaActivity, AgendaDay, Priority
from app.models.api_secret import AuditAction
from app.models.area import Area
from app.models.sensitivity import Sensitivity
from app.repositories.agenda_repository import AgendaRepository
from app.schemas.agenda import AgendaSummaryDay
from app.schemas.tag import TagSummary
from app.services.tag_service import TagService

MAX_RANGE_DAYS = 366
MAX_ACTIVITIES_PER_DAY = 100


class AgendaService:
    def __init__(self, session: Session, actor: Actor) -> None:
        self.session = session
        self.actor = actor
        self.access = AccessGuard(session, actor)
        self.agenda = AgendaRepository(session)
        self.tags = TagService(session)

    def summarize(self, start: date, end: date) -> list[AgendaSummaryDay]:
        if start > end:
            raise AppError(
                code="AGENDA_INVALID_RANGE",
                message="A data inicial precisa ser anterior à data final.",
                status_code=422,
            )
        if (end - start).days + 1 > MAX_RANGE_DAYS:
            raise AppError(
                code="AGENDA_RANGE_TOO_LARGE",
                message="O período máximo consultado é de um ano.",
                status_code=422,
            )

        day_criteria = self._both_areas_criteria()
        activity_criteria = self.access.optional_visible(Area.ACTIVITY)

        notes = (
            set(self.agenda.note_days(self.actor.user_id, start, end, day_criteria))
            if day_criteria is not None
            else set()
        )
        totals = (
            {
                day: (total, done, rank)
                for day, total, done, rank in self.agenda.activity_totals(
                    self.actor.user_id, start, end, activity_criteria
                )
            }
            if activity_criteria is not None
            else {}
        )
        tags_by_day = (
            self._visible_day_tags(start, end) if day_criteria is not None else {}
        )

        summaries: list[AgendaSummaryDay] = []
        for day in sorted(notes | set(totals) | set(tags_by_day)):
            total, done, rank = totals.get(day, (0, 0, 0))
            summaries.append(
                AgendaSummaryDay(
                    day=day,
                    has_note=day in notes,
                    activities_total=total,
                    activities_done=done,
                    highest_priority=_priority_from_rank(rank) if total else None,
                    tags=tags_by_day.get(day, []),
                )
            )
        return summaries

    def _both_areas_criteria(self) -> list | None:
        """Critérios do dia; 403 só quando a credencial não tem dia nem atividade."""
        day_criteria = self.access.optional_visible(Area.DAY)
        if day_criteria is None and self.access.optional_visible(Area.ACTIVITY) is None:
            self.access.visible(Area.DAY)
        return day_criteria

    def _visible_day_tags(
        self, start: date, end: date
    ) -> dict[date, list[TagSummary]]:
        """Tags dos dias visíveis: dia acima do nível não aparece nem pelas tags."""
        read_level = self.access.read_level(Area.DAY)
        tags_by_day = self.tags.day_tags(
            self.actor.user_id,
            start,
            end,
        )
        if read_level is Sensitivity.ALL:
            return tags_by_day
        levels = self.agenda.day_levels(self.actor.user_id, start, end)
        return {
            day: tags
            for day, tags in tags_by_day.items()
            if levels.get(day, Sensitivity.PUBLIC) <= read_level
        }

    def get_day(
        self, day: date
    ) -> tuple[AgendaDay | None, list[AgendaActivity], list[TagSummary]]:
        day_criteria = self._both_areas_criteria()
        activity_criteria = self.access.optional_visible(Area.ACTIVITY)

        note_row = None
        tags: list[TagSummary] = []
        if day_criteria is not None:
            note_row = self.agenda.get_day(self.actor.user_id, day, day_criteria)
            hidden_row = (
                note_row is None
                and self.agenda.get_day(self.actor.user_id, day) is not None
            )
            if not hidden_row:
                tags = self.tags.day_tags(
                    self.actor.user_id, day, day
                ).get(day, [])

        activities = (
            self.agenda.list_activities(self.actor.user_id, day, activity_criteria)
            if activity_criteria is not None
            else []
        )
        return note_row, activities, tags

    def set_day_tags(self, day: date, tag_ids: list[int]) -> list[TagSummary]:
        row = self._get_day_row_for_write(day)
        level = row.sensitivity if row is not None else Sensitivity.PUBLIC
        self.access.ensure_write(
            Area.DAY,
            level,
            target_type="agenda_day",
            target_id=row.id if row is not None else None,
        )
        tags = self.tags.set_day_tags(self.actor.user_id, day, tag_ids)
        self.session.commit()
        return tags

    def save_note(
        self,
        day: date,
        note: str | None,
        *,
        sensitivity: Sensitivity | None = None,
    ) -> AgendaDay | None:
        cleaned = note.rstrip() if note is not None else None
        if cleaned is not None and not cleaned.strip():
            cleaned = None

        day_criteria = self.access.visible(Area.DAY)
        row = self.agenda.get_day(self.actor.user_id, day, day_criteria)
        if row is None and self.agenda.get_day(self.actor.user_id, day) is not None:
            raise AppError(
                code="AGENDA_DAY_NOT_FOUND",
                message="Dia não encontrado.",
                status_code=404,
            )

        if cleaned is None:
            if row is not None:
                self.access.ensure_write(
                    Area.DAY,
                    row.sensitivity,
                    target_type="agenda_day",
                    target_id=row.id,
                    action=AuditAction.DELETE,
                )
                self.agenda.delete_day(self.actor.user_id, day)
            self.session.commit()
            return None

        if row is None:
            self.access.ensure_create(Area.DAY, target_type="agenda_day")
            row = AgendaDay(
                user_id=self.actor.user_id,
                day=day,
                note=cleaned,
                sensitivity=sensitivity or Sensitivity.PUBLIC,
            )
            self.agenda.add(row)
            self.session.flush()
            self.access.record_created(Area.DAY, "agenda_day", row.id)
        else:
            self.access.ensure_write(
                Area.DAY,
                row.sensitivity,
                target_type="agenda_day",
                target_id=row.id,
            )
            if sensitivity is not None:
                self.access.ensure_new_level(Area.DAY, sensitivity)
                row.sensitivity = sensitivity
            row.note = cleaned

        self.session.commit()
        return row

    def create_activity(
        self,
        day: date,
        title: str,
        start_time: time | None,
        priority: Priority,
        *,
        sensitivity: Sensitivity = Sensitivity.PUBLIC,
    ) -> AgendaActivity:
        self.access.ensure_create(Area.ACTIVITY, target_type="activity")
        if self.agenda.count_activities(self.actor.user_id, day) >= MAX_ACTIVITIES_PER_DAY:
            raise AppError(
                code="AGENDA_ACTIVITY_LIMIT",
                message="Este dia já atingiu o limite de atividades.",
                status_code=409,
            )

        activity = AgendaActivity(
            user_id=self.actor.user_id,
            day=day,
            title=title,
            start_time=start_time,
            priority=priority,
            sensitivity=sensitivity,
        )
        self.agenda.add(activity)
        self.session.flush()
        self.access.record_created(Area.ACTIVITY, "activity", activity.id)
        self.session.commit()
        return activity

    def update_activity(
        self,
        activity_id: int,
        *,
        title: str | None = None,
        start_time: time | None = None,
        change_start_time: bool = False,
        priority: Priority | None = None,
        is_done: bool | None = None,
        sensitivity: Sensitivity | None = None,
    ) -> AgendaActivity:
        activity = self._get_activity_or_fail(activity_id)
        self.access.ensure_write(
            Area.ACTIVITY,
            activity.sensitivity,
            target_type="activity",
            target_id=activity.id,
        )

        if title is not None:
            activity.title = title
        if change_start_time:
            activity.start_time = start_time
        if priority is not None:
            activity.priority = priority
        if is_done is not None:
            activity.is_done = is_done
        if sensitivity is not None:
            self.access.ensure_new_level(Area.ACTIVITY, sensitivity)
            activity.sensitivity = sensitivity

        self.session.commit()
        return activity

    def delete_activity(self, activity_id: int) -> None:
        activity = self._get_activity_or_fail(activity_id)
        self.access.ensure_write(
            Area.ACTIVITY,
            activity.sensitivity,
            target_type="activity",
            target_id=activity.id,
            action=AuditAction.DELETE,
        )
        day = activity.day
        self.agenda.remove(activity)
        self.session.commit()
        self._drop_day_without_note(day)

    def _get_day_row_for_write(self, day: date) -> AgendaDay | None:
        day_criteria = self.access.visible(Area.DAY)
        row = self.agenda.get_day(self.actor.user_id, day, day_criteria)
        if row is None and self.agenda.get_day(self.actor.user_id, day) is not None:
            raise AppError(
                code="AGENDA_DAY_NOT_FOUND",
                message="Dia não encontrado.",
                status_code=404,
            )
        return row

    def _drop_day_without_note(self, day: date) -> None:
        day_criteria = self.access.optional_visible(Area.DAY)
        if day_criteria is None:
            return
        row = self.agenda.get_day(self.actor.user_id, day, day_criteria)
        if row is None or row.note is not None:
            return
        if self.agenda.count_activities(self.actor.user_id, day) > 0:
            return
        self.agenda.delete_day(self.actor.user_id, day)
        self.session.commit()

    def _get_activity_or_fail(self, activity_id: int) -> AgendaActivity:
        activity = self.agenda.get_activity(
            self.actor.user_id,
            activity_id,
            self.access.visible(Area.ACTIVITY),
        )
        if activity is None:
            raise AppError(
                code="AGENDA_ACTIVITY_NOT_FOUND",
                message="Atividade não encontrada.",
                status_code=404,
            )
        return activity


def _priority_from_rank(rank: int) -> Priority:
    if rank >= 2:
        return Priority.HIGH
    if rank == 1:
        return Priority.MEDIUM
    return Priority.LOW
