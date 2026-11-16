"""Trashy - API backend.

Avvio:  uvicorn app.main:app --reload     (dalla cartella backend/)
Docs:   http://localhost:8000/docs
"""
from typing import Literal

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from . import classifier, config, points
from .rules import CATEGORIES, MUNICIPALITY, localized

Lang = Literal["it", "de"]

app = FastAPI(title="Trashy API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)

NOT_FOUND = {
    "it": "Non ho capito di che rifiuto si tratta. Prova a descriverlo in un altro modo "
          "(es. \"bottiglia di vetro\", \"vecchio smartphone\").",
    "de": "Ich habe nicht verstanden, um welchen Abfall es geht. Versuche es anders zu beschreiben "
          "(z. B. \"Glasflasche\", \"altes Handy\").",
}


# ---------- Modelli ----------

class AskRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500, examples=["Dove butto le capsule del caffè?"])
    lang: Lang | None = Field(None, description="Se assente viene rilevata dal testo")
    lat: float | None = Field(None, description="Posizione utente: se presente restituisce anche i punti vicini")
    lon: float | None = None
    radius_m: int = Field(3000, ge=100, le=50000)


class Category(BaseModel):
    id: str
    name: str
    bin: str
    color: str
    instructions: str
    has_points: bool


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
        "ai_enabled": config.AI_ENABLED,
        "ai_model": config.AI_MODEL if config.AI_ENABLED else None,
        "points_count": points.count(),
    }


@app.get("/api/categories", response_model=list[Category])
def list_categories(lang: Lang = "it"):
    return [localized(cid, lang) for cid in CATEGORIES]


@app.get("/api/categories/{category_id}", response_model=Category)
def get_category(category_id: str, lang: Lang = "it"):
    if category_id not in CATEGORIES:
        raise HTTPException(404, "Categoria non trovata")
    return localized(category_id, lang)


@app.post("/api/ask", response_model=AskResponse)
def ask(req: AskRequest):
    lang = req.lang or classifier.detect_lang(req.text)
    result = classifier.classify(req.text)
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


@app.get("/api/points", response_model=list[Point])
def list_points(
    lat: float,
    lon: float,
    radius_m: int = Query(3000, ge=100, le=50000),
    category: str | None = Query(None, description="Id categoria, es. 'vetro_metallo'"),
    kind: Literal["container", "centre", "pharmacy"] | None = None,
    limit: int = Query(20, ge=1, le=200),
):
    if category and category not in CATEGORIES:
        raise HTTPException(404, "Categoria non trovata")
    return points.nearby(lat, lon, radius_m, category=category, kind=kind, limit=limit)
