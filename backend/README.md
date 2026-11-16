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
  ai.py          client LLM compatibile OpenAI (validazione, cache, tetto giornaliero)
  ratelimit.py   rate limiting per IP
  points.py      ricerca dei punti vicini in SQLite
data/
  rules_bolzano.json   categorie, istruzioni IT/DE, pattern regex, filtri per i punti
  trashy.db            creato da import_osm
scripts/
  import_osm.py  Overpass API -> SQLite
```

## AI

`AI_ENABLED=false` → solo regex. Con `true`: prima le regex, l'LLM solo se le regex non trovano nulla
(`AI_FIRST=true` per chiamarlo sempre). Se l'LLM non risponde o la quota è finita si torna alle regex.
L'AI **sceglie solo la categoria**: le istruzioni mostrate all'utente vengono sempre da `rules_bolzano.json`.

Google AI Studio (tier gratuito, chiave da https://aistudio.google.com/apikey):
```
AI_ENABLED=true
AI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/
AI_API_KEY=<la tua chiave>
AI_MODEL=gemini-2.5-flash
AI_REASONING_EFFORT=none
AI_DAILY_LIMIT=200      # tienilo sotto la quota giornaliera mostrata in AI Studio
```
Note: le quote gratuite cambiano spesso (controllale in AI Studio). Nel tier gratuito Google può usare
i testi inviati per migliorare i suoi prodotti: per la privacy totale usa Ollama in locale.
Limita la chiave alla sola "Generative Language API" nella Google Cloud Console.

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
`lang`, `lat`, `lon` e `radius_m` sono facoltativi (se manca, `lang` viene rilevata dal testo). `text` max 200 caratteri.
Il frontend deve gestire **HTTP 429** (troppe richieste) mostrando un messaggio all'utente.
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

## Sicurezza e anti-abuso

- **L'AI non è usabile come chatbot gratuito**: il modello può solo scegliere un id da una lista chiusa;
  la risposta viene validata (categoria fuori lista → "non ho capito", `item` ripulito e max 60 caratteri)
  e il testo mostrato viene sempre dal file delle regole. Una prompt injection non produce testo libero.
- **Chiave API** solo nel `.env` sul server: il frontend non la vede mai.
- **Rate limiting per IP**: `/api/ask` 10/min, `/api/points` 60/min (`RATE_LIMIT_*`). Oltre il limite: HTTP 429.
- **Tetto giornaliero globale** di chiamate AI (`AI_DAILY_LIMIT`): protegge quota e costi anche se
  qualcuno usa molti IP. Superato il tetto si usano le regex.
- **Cache** delle domande uguali, **testo max 200 caratteri**, **max_tokens** e **timeout** sulle risposte.
- **In produzione**: `CORS_ORIGINS` con il solo dominio del frontend e `DOCS_ENABLED=false`.

Limiti da conoscere:
- Un'API pubblica non si può riservare al 100% al proprio frontend: CORS blocca solo gli altri siti nel
  browser, non chi chiama con script. Le protezioni vere sono quelle sopra (output inutile fuori dall'app,
  rate limit, tetto giornaliero).
- Rate limit e tetto sono in memoria: si azzerano al riavvio e valgono per un solo processo uvicorn.
- Dietro un reverse proxy (nginx, Cloudflare Tunnel) avvia con
  `uvicorn app.main:app --proxy-headers --forwarded-allow-ips=127.0.0.1`, altrimenti tutti gli utenti
  hanno l'IP del proxy e condividono lo stesso limite.

## Regole

`data/rules_bolzano.json` contiene regole indicative: **vanno verificate con la guida ufficiale SEAB** prima della pubblicazione.
I `patterns` sono regex applicate al testo in minuscolo, senza accenti e senza umlaut (`Kühlschrank` → `kuhlschrank`). Se più pattern corrispondono vince il match più lungo.
Per aggiungere un altro comune basta creare un nuovo JSON e impostare `RULES_FILE`.
