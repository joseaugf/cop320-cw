from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://postgres:postgres@localhost:5432/petshop_catalog"
    feature_flag_service_url: str = "http://localhost:3001"
    otel_exporter_otlp_endpoint: str = "http://localhost:4317"
    otel_service_name: str = "catalog-service"
    otel_service_namespace: str = "petshop-demo"
    port: int = 8001

    class Config:
        env_file = ".env"


settings = Settings()
