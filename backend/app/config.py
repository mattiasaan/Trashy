import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

RULES_PATH = BASE_DIR / os.getenv("RULES_FILE", "data/rules_bolzano.json")
DB_PATH = BASE_DIR / os.getenv("DB_FILE", "data/trashy.db")

# AI (qualsiasi API compatibile OpenAI: Google AI Studio/Gemini, OpenAI, Ollama, ...)
AI_ENABLED = os.getenv("AI_ENABLED", "false").lower() == "true"
AI_BASE_URL = os.getenv("AI_BASE_URL") or None  # None = OpenAI ufficiale
AI_API_KEY = os.getenv("AI_API_KEY", "not-needed")
AI_MODEL = os.getenv("AI_MODEL", "gemini-2.5-flash")
AI_TIMEOUT = float(os.getenv("AI_TIMEOUT", "15"))
# false = prima le regex, l'AI solo se le regex non trovano nulla (risparmia quota)
AI_FIRST = os.getenv("AI_FIRST", "false").lower() == "true"
AI_MAX_TOKENS = int(os.getenv("AI_MAX_TOKENS", "300"))
# Vuoto = non inviato. Gemini 2.5 Flash: "none" (niente ragionamento, più veloce ed economico)
AI_REASONING_EFFORT = os.getenv("AI_REASONING_EFFORT") or None
# Tetto globale di chiamate AI al giorno (tutti gli utenti insieme). Superato -> solo regex
AI_DAILY_LIMIT = int(os.getenv("AI_DAILY_LIMIT", "200"))
# Tetto di chiamate AI al giorno per singolo IP: un solo client non può esaurire il tetto globale
AI_DAILY_LIMIT_PER_IP = int(os.getenv("AI_DAILY_LIMIT_PER_IP", "15"))

# Rate limiting per IP (richieste al minuto). Non troppo basso: sulla rete mobile
# molti utenti condividono lo stesso IP (CGNAT degli operatori)
RATE_LIMIT_ASK = int(os.getenv("RATE_LIMIT_ASK", "20"))
RATE_LIMIT_POINTS = int(os.getenv("RATE_LIMIT_POINTS", "60"))

# Default sicuri: nessuna origine browser ammessa, /docs nascosto
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()]
DOCS_ENABLED = os.getenv("DOCS_ENABLED", "false").lower() == "true"
# true SOLO se il server è raggiungibile esclusivamente tramite Cloudflare (Tunnel su 127.0.0.1):
# usa l'header CF-Connecting-IP (impostato da Cloudflare, non falsificabile dal client) come IP reale
TRUST_CF_CONNECTING_IP = os.getenv("TRUST_CF_CONNECTING_IP", "false").lower() == "true"
