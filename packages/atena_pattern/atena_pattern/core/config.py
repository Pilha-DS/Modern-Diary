from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class AthenaSettings(BaseSettings):
    """Configuração base do padrão.

    O projeto herda esta classe e acrescenta as configurações dele. Os campos
    daqui são os que o núcleo (sessão, secrets, envelope, CORS) precisa para
    funcionar.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "API"
    environment: Literal["development", "test", "production"] = "development"
    database_url: str
    secret_key: str = Field(min_length=32)
    access_token_expire_minutes: int = Field(default=60, gt=0)
    cors_origins: str = ""

    #: Prefixo do token de uma credencial de integração. O projeto pode trocar
    #: o prefixo sem mexer no motor de permissões.
    secret_token_prefix: str = "mds_"

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


_settings: AthenaSettings | None = None


def configure(settings: AthenaSettings) -> AthenaSettings:
    """Registra a configuração usada pelo núcleo nesta execução."""
    global _settings
    _settings = settings
    return settings


def get_settings() -> AthenaSettings:
    if _settings is None:
        raise RuntimeError(
            "Configuração ausente: chame atena_pattern.configure(settings) "
            "ou crie a aplicação com create_app(settings)."
        )
    return _settings


def reset_settings() -> None:
    """Descarta a configuração registrada. Uso em teste."""
    global _settings
    _settings = None
