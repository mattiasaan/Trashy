import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

RULES_PATH = BASE_DIR / os.getenv("RULES_FILE", "data/rules_bolzano.json")
DB_PATH = BASE_DIR / os.getenv("DB_FILE", "data/trashy.db")

# AI (qualsiasi API compatibile OpenAI: OpenAI, Ollama, Groq, ...)
AI_ENABLED = os.getenv("AI_ENABLED", "false").lower() == "true"
AI_BASE_URL = os.getenv("AI_BASE_URL") or None  # None = OpenAI ufficiale
AI_API_KEY = os.getenv("AI_API_KEY", "not-needed")
AI_MODEL = os.getenv("AI_MODEL", "gpt-4o-mini")
AI_TIMEOUT = float(os.getenv("AI_TIMEOUT", "30"))

CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",")]
