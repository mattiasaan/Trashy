"""Trashy - API backend.

Avvio:  uvicorn app.main:app --reload     (dalla cartella backend/)
Docs:   http://localhost:8000/docs
"""
import logging
import socket
from contextlib import asynccontextmanager
from typing import Literal

from fastapi import Depends, FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from . import ai, classifier, config, points
from .ratelimit import RateLimiter, client_ip
from .rules import CATEGORIES, MUNICIPALITY, SOURCE, localized, localized_notes

# Uvicorn configura solo i suoi logger: senza questo i log INFO dell'app non si vedono
logging.basicConfig(
    level=config.LOG_LEVEL,
    format="%(asctime)s %(levelname)-7s [%(name)s] %(message)s",
    datefmt="%H:%M:%S",
)
for _name in ("httpx", "httpx2", "httpcore"):  # richieste HTTP del client openai
    logging.getLogger(_name).setLevel(logging.WARNING)
log = logging.getLogger("trashy")

Lang = Literal["it", "de"]


def _lan_ip() -> str | None:
    """IP del PC nella rete locale (nessun pacchetto viene inviato)."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("192.0.2.1", 80))
            return s.getsockname()[0]
    except OSError:
        return None


def _log_startup():
    log.info("===== Trashy API - configurazione =====")
    log.info("AI_ENABLED=%s  AI_FIRST=%s", config.AI_ENABLED, config.AI_FIRST)
    if config.AI_ENABLED:
        log.info("AI_BASE_URL=%s", config.AI_BASE_URL or "(OpenAI ufficiale)")
        log.info("AI_MODEL=%s  AI_REASONING_EFFORT=%s  AI_MAX_TOKENS=%d  AI_TIMEOUT=%ss",
                 config.AI_MODEL, config.AI_REASONING_EFFORT, config.AI_MAX_TOKENS, config.AI_TIMEOUT)
        log.info("AI_API_KEY=%s", config.masked_key())
        log.info("Tetti AI: %d/giorno totali, %d/giorno per IP",
                 config.AI_DAILY_LIMIT, config.AI_DAILY_LIMIT_PER_IP)
        if config.masked_key() == "<VUOTA>" and config.AI_BASE_URL and "localhost" not in config.AI_BASE_URL:
            log.error("AI_API_KEY è vuota nel file %s: tutte le chiamate falliranno",
                      config.BASE_DIR / ".env")
        if not config.AI_FIRST:
            log.warning("AI_FIRST=false: l'AI viene chiamata SOLO quando le regex non trovano nulla")
    else:
        log.warning("AI disattivata (AI_ENABLED=false in %s): risponderò sempre con le regex",
                    config.BASE_DIR / ".env")
    log.info("Punti di raccolta nel DB: %d", points.count())
    ip = _lan_ip()
    if ip:
        log.info("Dalla LAN (es. Expo Go): EXPO_PUBLIC_API_URL=http://%s:8000  "
                 "(funziona solo se avvii uvicorn con --host 0.0.0.0)", ip)
    log.info("=======================================")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    _log_startup()
    yield


docs = {} if config.DOCS_ENABLED else {"docs_url": None, "redoc_url": None, "openapi_url": None}
app = FastAPI(title="Trashy API", version="0.1.0", lifespan=lifespan, **docs)
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)

limit_ask = RateLimiter(config.RATE_LIMIT_ASK)
limit_points = RateLimiter(config.RATE_LIMIT_POINTS)

NOT_FOUND = {
    "it": "Non ho capito di che rifiuto si tratta. Prova a descriverlo in un altro modo "
          "(es. \"bottiglia di vetro\", \"vecchio smartphone\").",
    "de": "Ich habe nicht verstanden, um welchen Abfall es geht. Versuche es anders zu beschreiben "
          "(z. B. \"Glasflasche\", \"altes Handy\").",
}


# ---------- Modelli ----------

class AskRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=200,examples=["Dove butto le capsule del caffè?"])
    lang: Lang | None = Field(None, description="Se assente viene rilevata dal testo")
    lat: float | None = Field(None, ge=-90, le=90, description="Posizione utente: se presente (con lon) restituisce anche i punti vicini")
    lon: float | None = Field(None, ge=-180, le=180)
    radius_m: int = Field(3000, ge=100, le=50000)


class Category(BaseModel):
    id: str
    name: str
    bin: str
    color: str
    instructions: str
    has_points: bool
    ref: str | None = Field(None, description="Articolo del regolamento comunale, es. 'Art. 16'")


class Note(BaseModel):
    id: str
    text: str
    ref: str | None


class Info(BaseModel):
    municipality: str
    source: str | None
    map_attribution: str = Field(description="Da mostrare sulla mappa (obbligatoria per la licenza ODbL di OSM)")
    notes: list[Note]


class Point(BaseModel):
    id: str
    lat: float
    lon: float
    kind: str
    name: str | None
    materials: list[str]
    opening_hours: str | None
    address: str | None
    distance_m: int


class AskResponse(BaseModel):
    lang: Lang
    found: bool
    source: Literal["ai", "regex"]
    item: str | None
    category: Category | None
    answer: str
    points: list[Point] | None = Field(None, description="Solo se sono state inviate lat/lon")


# ---------- Endpoint ----------

@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "municipality": MUNICIPALITY,
        "points_count": points.count(),
        "ai_enabled": config.AI_ENABLED,
        "ai_first": config.AI_FIRST,
        # dettagli (modello, ultimo errore) solo in sviluppo: in produzione non si espongono
        **({"ai": ai.status()} if config.DOCS_ENABLED or config.AI_DEBUG else {}),
    }


@app.get("/api/info", response_model=Info)
def info(lang: Lang = "it"):
    """Fonte delle regole e note generali (residenza, multe per abbandono, ...)."""
    return {
        "municipality": MUNICIPALITY,
        "source": SOURCE,
        "map_attribution": "© OpenStreetMap contributors",
        "notes": localized_notes(lang),
    }


@app.get("/api/categories", response_model=list[Category])
def list_categories(lang: Lang = "it"):
    return [localized(cid, lang) for cid in CATEGORIES]


@app.get("/api/categories/{category_id}", response_model=Category)
def get_category(category_id: str, lang: Lang = "it"):
    if category_id not in CATEGORIES:
        raise HTTPException(404, "Categoria non trovata")
    return localized(category_id, lang)


@app.post("/api/ask", response_model=AskResponse, dependencies=[Depends(limit_ask)])
def ask(req: AskRequest, request: Request):
    lang = req.lang or classifier.detect_lang(req.text)
    result = classifier.classify(req.text, client_ip(request))
    cid = result["category"]

    if cid is None:
        return AskResponse(lang=lang, found=False, source=result["source"],
                           item=None, category=None, answer=NOT_FOUND[lang])

    category = localized(cid, lang)
    near = None
    if req.lat is not None and req.lon is not None:
        near = points.nearby(req.lat, req.lon, req.radius_m, category=cid, limit=10)

    return AskResponse(
        lang=lang,
        found=True,
        source=result["source"],
        item=result["item"],
        category=category,
        answer=f"{category['name']}: {category['instructions']}",
        points=near,
    )


@app.get("/api/points", response_model=list[Point], dependencies=[Depends(limit_points)])
def list_points(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    radius_m: int = Query(3000, ge=100, le=50000),
    category: str | None = Query(None, description="Id categoria, es. 'vetro_metallo'"),
    kind: Literal["container", "centre", "pharmacy"] | None = None,
    limit: int = Query(20, ge=1, le=200),
):
    if category and category not in CATEGORIES:
        raise HTTPException(404, "Categoria non trovata")
    return points.nearby(lat, lon, radius_m, category=category, kind=kind, limit=limit)
