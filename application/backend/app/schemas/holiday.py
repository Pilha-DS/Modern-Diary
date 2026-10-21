from datetime import date

from pydantic import BaseModel, ConfigDict, Field, field_serializer


class HolidaySyncRequest(BaseModel):
    country_iso2: str = Field(
        min_length=2,
        max_length=2,
        pattern=r"^[A-Za-z]{2}$",
        examples=["BR"],
        description="País da nacionalidade, com duas letras",
    )


class HolidayResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    day: date
    name: str
    local_name: str | None
    country_iso2: str

    @field_serializer("day")
    def serialize_day(self, value: date) -> str:
        return value.isoformat()
