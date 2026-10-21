from enum import IntEnum

from sqlalchemy import Integer
from sqlalchemy.types import TypeDecorator


class Sensitivity(IntEnum):
    """Nível de sensibilidade de um dado e limite de leitura de uma secret.

    A ordem é a hierarquia: um limite de leitura libera o próprio nível e os
    anteriores. `ALL` só existe como limite de permissão — nenhum registro do
    sistema é gravado como `ALL`.
    """

    PUBLIC = 1
    BASIC = 2
    MODERATE = 3
    COMPLEX = 4
    SECRET = 5
    ALL = 6

    @property
    def api_value(self) -> str:
        """Valor usado na API, em português."""
        return API_VALUES[self]

    @classmethod
    def from_api(cls, value: str) -> "Sensitivity":
        normalized = value.strip().lower()
        for level, api_value in API_VALUES.items():
            if normalized == api_value:
                return level
        for level in cls:
            if normalized == level.name.lower():
                return level
        raise ValueError(f"nível de sensibilidade desconhecido: {value}")


API_VALUES: dict[Sensitivity, str] = {
    Sensitivity.PUBLIC: "publico",
    Sensitivity.BASIC: "basico",
    Sensitivity.MODERATE: "moderado",
    Sensitivity.COMPLEX: "complexo",
    Sensitivity.SECRET: "sigiloso",
    Sensitivity.ALL: "all",
}

# Níveis aceitos em um registro. `ALL` é só limite de permissão.
DATA_LEVELS: tuple[Sensitivity, ...] = (
    Sensitivity.PUBLIC,
    Sensitivity.BASIC,
    Sensitivity.MODERATE,
    Sensitivity.COMPLEX,
    Sensitivity.SECRET,
)


class SensitivityType(TypeDecorator):
    """Grava o nível pelo valor numérico, para a comparação seguir a hierarquia.

    Um ENUM por nome seria comparado em ordem alfabética no banco — `PUBLIC`
    ficaria acima de `COMPLEX`. Com inteiro, `<=` significa exatamente
    "este nível ou um mais aberto".
    """

    impl = Integer
    cache_ok = True

    def process_bind_param(self, value: Sensitivity | int | None, dialect) -> int | None:
        if value is None:
            return None
        return int(value)

    def process_result_value(self, value: int | None, dialect) -> Sensitivity | None:
        if value is None:
            return None
        return Sensitivity(value)
