import os
from dotenv import load_dotenv

# Load .env early so env vars exist before Config is evaluated
load_dotenv()

class Config:
    # Secrets/settings pulled from environment
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-only-change-me")
    SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL", "sqlite:///app.sqlite3")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    MAX_CONTENT_LENGTH = int(os.environ.get("MAX_CONTENT_LENGTH", 16 * 1024 * 1024))
    MAX_FORM_MEMORY_SIZE = int(os.environ.get("MAX_FORM_MEMORY_SIZE", 16 * 1024 * 1024))
