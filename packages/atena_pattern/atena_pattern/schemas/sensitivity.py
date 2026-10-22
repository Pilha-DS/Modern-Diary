from typing import Annotated

from pydantic import BeforeValidator, PlainSerializer

from atena_pattern.models.sensitivity import Sensitivity


def _parse_level(value: object) -> Sensitivity:
    if isinstance(value, Sensitivity):
        return value
    if isinstance(value, str):
        try:
            return Sensitivity.from_api(value)
        except ValueError as error:
            raise ValueError(str(error)) from error
    raise ValueError("informe o nível como texto (ex.: 'complexo')")


def _parse_data_level(value: object) -> Sensitivity:
    level = _parse_level(value)
    if level is Sensitivity.ALL:
        raise ValueError("'all' é limite de permissão, não nível de registro")
    return level


def _serialize_level(level: Sensitivity) -> str:
    return level.api_value


LevelSerializer = PlainSerializer(_serialize_level, return_type=str)

#: Limite de leitura de uma secret: aceita `publico` até `all`.
ReadLevel = Annotated[Sensitivity, BeforeValidator(_parse_level), LevelSerializer]

#: Nível de um registro: aceita `publico` até `sigiloso`.
DataLevel = Annotated[Sensitivity, BeforeValidator(_parse_data_level), LevelSerializer]
