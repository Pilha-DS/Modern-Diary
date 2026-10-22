"""Configuração do Modern Diary.

Só o que é do projeto entra aqui. Tudo o que o núcleo precisa (banco, sessão,
secrets, CORS, envelope) vem de `AthenaSettings`.
"""

from atena_pattern.core.config import AthenaSettings


class Settings(AthenaSettings):
    app_name: str = "Modern Diary API"

    #: Prefixo do token das credenciais de integração do Modern Diary.
    secret_token_prefix: str = "mds_"
