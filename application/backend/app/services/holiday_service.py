from datetime import date

from sqlalchemy.orm import Session

from atena_pattern.core.errors import AppError
from app.data.holidays import ENABLED_COUNTRIES, fetch_public_holidays, is_enabled
from app.models.holiday import Holiday
from app.repositories.holiday_repository import HolidayRepository

# O ano corrente e o seguinte cobrem o calendário sem nova consulta à fonte.
SYNC_YEARS_AHEAD = 1


class HolidayService:
    """Feriados do usuário, guardados no banco a partir da fonte externa."""

    def __init__(self, session: Session, user_id: int) -> None:
        self.session = session
        self.user_id = user_id
        self.holidays = HolidayRepository(session)

    def sync(
        self,
        iso2: str,
        *,
        today: date | None = None,
    ) -> tuple[list[Holiday], list[int]]:
        code = iso2.strip().upper()
        if not is_enabled(code):
            enabled = ", ".join(ENABLED_COUNTRIES.values())
            raise AppError(
                code="HOLIDAY_COUNTRY_NOT_ENABLED",
                message=f"Os feriados estão disponíveis para {enabled}.",
                status_code=422,
            )

        current = today or date.today()
        years = [current.year + offset for offset in range(SYNC_YEARS_AHEAD + 1)]

        # Busca tudo antes de trocar o banco: se a fonte falhar, nada muda.
        rows: list[Holiday] = []
        seen: set[tuple[date, str]] = set()
        for year in years:
            for item in fetch_public_holidays(year, code):
                row = self._parse_holiday(item, code)
                if row is None:
                    continue
                key = (row["day"], row["name"])
                if key in seen:
                    continue
                seen.add(key)
                rows.append(Holiday(user_id=self.user_id, **row))

        self.holidays.replace_all(self.user_id, rows)
        self.session.commit()
        return rows, years

    def names_between(self, start: date, end: date) -> dict[date, str]:
        """Nome do feriado por dia, para o resumo e o detalhe da agenda."""
        names: dict[date, list[str]] = {}
        for holiday in self.holidays.list_between(self.user_id, start, end):
            names.setdefault(holiday.day, []).append(holiday.display_name)
        return {day: " / ".join(names) for day, names in names.items()}

    def name_on(self, day: date) -> str | None:
        holidays = self.holidays.get_on_day(self.user_id, day)
        if not holidays:
            return None
        return " / ".join(holiday.display_name for holiday in holidays)

    @staticmethod
    def _parse_holiday(item: dict, iso2: str) -> dict | None:
        if item.get("global") is False:
            # Feriado regional não é do país inteiro: não entra no calendário.
            return None
        raw_date = item.get("date")
        name = (item.get("name") or item.get("localName") or "").strip()
        if not raw_date or not name:
            return None
        try:
            day = date.fromisoformat(str(raw_date))
        except ValueError:
            return None
        local_name = (item.get("localName") or "").strip() or None
        return {
            "country_iso2": iso2,
            "day": day,
            "name": name[:160],
            "local_name": local_name[:160] if local_name else None,
        }
