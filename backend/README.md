# Trashy – Backend

API FastAPI per l'assistente rifiuti di Bolzano (IT/DE).

## Avvio

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Linux/Raspberry: source .venv/bin/activate
pip install -r requirements.txt
copy .env.example .env          # Linux: cp .env.example .env

python -m scripts.import_osm    # scarica i punti di raccolta (rilancia per aggiornare)
uvicorn app.main:app --reload   # --host 0.0.0.0 per accedere da altri dispositivi
```

Documentazione interattiva: http://localhost:8000/docs

## Struttura

```
app/
  main.py        endpoint e modelli di risposta
  config.py      variabili da .env
  rules.py       carica data/rules_bolzano.json
  classifier.py  rilevamento lingua + classificazione (regex, oppure AI con fallback alle regex)
  ai.py          client LLM compatibile OpenAI
  points.py      ricerca dei punti vicini in SQLite
data/
  rules_bolzano.json   categorie, istruzioni IT/DE, pattern regex, filtri per i punti
  trashy.db            creato da import_osm
scripts/
  import_osm.py  Overpass API -> SQLite
```

## AI

`AI_ENABLED=false` → solo regex. Con `true` il testo va all'LLM; se l'LLM non risponde si torna alle regex.
L'AI **sceglie solo la categoria**: le istruzioni mostrate all'utente vengono sempre da `rules_bolzano.json`.

Ollama sul Raspberry Pi:
```
AI_ENABLED=true
AI_BASE_URL=http://localhost:11434/v1
AI_API_KEY=ollama
AI_MODEL=qwen2.5:3b
```
OpenAI: lascia `AI_BASE_URL` vuoto e imposta `AI_API_KEY` e `AI_MODEL`.

## API per il frontend

### `POST /api/ask` – domanda in linguaggio naturale
```json
{ "text": "Dove butto le capsule del caffè?", "lang": "it", "lat": 46.4983, "lon": 11.3548, "radius_m": 3000 }
```
`lang`, `lat`, `lon` e `radius_m` sono facoltativi (se manca, `lang` viene rilevata dal testo).
```json
{
  "lang": "it",
  "found": true,
  "source": "regex",
  "item": "capsule del caffe",
  "category": {
    "id": "residuo", "name": "Residuo", "bin": "Bidone grigio del residuo",
    "color": "#6b7280", "instructions": "Va nel residuo...", "has_points": false
  },
  "answer": "Residuo: Va nel residuo...",
  "points": []
}
```
- `found: false` → `category` è null e `answer` contiene un messaggio "non ho capito".
- `points` è valorizzato solo se invii `lat`/`lon`; lista vuota per i rifiuti raccolti porta a porta (`has_points: false`).

### `GET /api/points?lat=..&lon=..&radius_m=3000&category=vetro_metallo&kind=centre&limit=20`
Punti per la mappa, ordinati per distanza. `category` e `kind` (`container` | `centre` | `pharmacy`) sono facoltativi.
```json
[{ "id": "node/123", "lat": 46.49, "lon": 11.35, "kind": "container", "name": null,
   "materials": ["glass_bottles", "cans"], "opening_hours": null, "address": null, "distance_m": 160 }]
```

### `GET /api/categories?lang=de` – tutte le categorie (es. per una griglia "sfoglia")
### `GET /api/categories/{id}?lang=it` – una categoria
### `GET /api/health` – stato, AI attiva, numero di punti nel DB

## Regole

`data/rules_bolzano.json` contiene regole indicative: **vanno verificate con la guida ufficiale SEAB** prima della pubblicazione.
I `patterns` sono regex applicate al testo in minuscolo, senza accenti e senza umlaut (`Kühlschrank` → `kuhlschrank`). Se più pattern corrispondono vince il match più lungo.
Per aggiungere un altro comune basta creare un nuovo JSON e impostare `RULES_FILE`.
