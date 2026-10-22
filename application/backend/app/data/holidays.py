"""Fonte externa de feriados: Nager.Date, gratuita e sem chave.

A fonte entrega o ano inteiro de um país de uma vez. O resultado é gravado na
tabela `holiday`, então a agenda lê do banco em vez de consultar a internet.
País fora da lista habilitada não é sincronizado.
"""

import json
import urllib.error
import urllib.request
from typing import Any

from atena_pattern.core.errors import AppError

SOURCE_URL = "https://date.nager.at/api/v3/PublicHolidays"
SOURCE_TIMEOUT_SECONDS = 10
ENABLED_COUNTRIES: dict[str, str] = {
    "BR": "Brasil",
    "SE": "Suécia",
}


def is_enabled(iso2: str) -> bool:
    return iso2.upper() in ENABLED_COUNTRIES


def fetch_public_holidays(year: int, iso2: str) -> list[dict[str, Any]]:
    """Feriados globais do país no ano, como vieram da fonte."""
    request = urllib.request.Request(
        f"{SOURCE_URL}/{year}/{iso2}",
        headers={"Accept": "application/json", "User-Agent": "ModernDiary/1.0"},
    )
    try:
        with urllib.request.urlopen(
            request, timeout=SOURCE_TIMEOUT_SECONDS
        ) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, ValueError):
        raise AppError(
            code="HOLIDAY_SOURCE_UNAVAILABLE",
            message=(
                "Não foi possível consultar os feriados agora. "
                "Tente novamente em instantes."
            ),
            status_code=502,
        ) from None

    if not isinstance(payload, list):
        raise AppError(
            code="HOLIDAY_SOURCE_INVALID",
            message="A fonte de feriados devolveu uma resposta inesperada.",
            status_code=502,
        )
    return [item for item in payload if isinstance(item, dict)]
