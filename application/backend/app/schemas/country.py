from pydantic import BaseModel, ConfigDict

MAX_SEARCH_LENGTH = 60


class CountryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    iso2: str
    iso3: str
    numeric_code: str | None
    name: str
    long_name: str | None
    native_name: str | None
    phone_code: str | None
    continent: str
    capital: str | None
    currency_code: str | None
    currency_symbol: str | None
    tld: str | None
    flag_emoji: str
