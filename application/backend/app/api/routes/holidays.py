from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from atena_pattern.api.deps import get_current_user
from atena_pattern.core.database import get_db
from atena_pattern.core.responses import api_response
from atena_pattern.models.user import User
from app.schemas.holiday import HolidayResponse, HolidaySyncRequest
from app.services.holiday_service import HolidayService

router = APIRouter(prefix="/holidays", tags=["holidays"])


@router.post("/sync", summary="Puxa os feriados do país e guarda no calendário")
def sync_holidays(
    payload: HolidaySyncRequest,
    request: Request,
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    holidays, years = HolidayService(session, user.id).sync(payload.country_iso2)
    return api_response(
        request,
        code="HOLIDAYS_SYNCED",
        data=[
            HolidayResponse.model_validate(holiday).model_dump(mode="json")
            for holiday in holidays
        ],
        message=f"{len(holidays)} feriados importados para o calendário.",
        meta={
            "country_iso2": payload.country_iso2.upper(),
            "years": years,
            "total": len(holidays),
        },
    )
