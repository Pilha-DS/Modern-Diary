from enum import StrEnum


class Area(StrEnum):
    """Área do sistema que pode ser liberada para uma secret.

    O valor é o nome usado na API. Uma área nova entra aqui e no registro de
    colunas de sensibilidade em `app.core.access`; o resto do sistema de
    permissões não muda.
    """

    KNOWLEDGE = "conhecimentos"
    NOTE = "notas"
    GOAL = "metas"
    DAY = "dias"
    ACTIVITY = "atividades"
