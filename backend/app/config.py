from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    supabase_url: str
    supabase_service_key: str
    jwt_secret: str
    port: int = 8000
    cors_origins: str = "*"
    pvp_active_grace_seconds: int = 15
    pvp_waiting_grace_seconds: int = 60
    pvp_closed_ttl_seconds: int = 60
    pvp_stale_waiting_seconds: int = 600
    pvp_queue_ttl_seconds: int = 90

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


try:
    settings = Settings()
except Exception as exc:
    raise SystemExit(
        "Missing required environment variables. Copy .env.example to .env and fill in "
        "SUPABASE_URL, SUPABASE_SERVICE_KEY, and JWT_SECRET."
    ) from exc
