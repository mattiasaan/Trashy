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
deploy/          file systemd per il Raspberry Pi
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

## Collegare il frontend

Due modi:

1. **Sviluppo** (es. Vite su `http://localhost:5173`): backend con `uvicorn app.main:app --reload`,
   nel `.env` metti `CORS_ORIGINS=http://localhost:5173` e nel frontend usa come base URL `http://localhost:8000`.
   Per provare dal telefono: `--host 0.0.0.0` e l'IP del PC (es. `http://192.168.1.20:8000`).
2. **Produzione / Raspberry** (consigliato): fai la build del frontend e imposta `FRONTEND_DIR=../frontend/dist`.
   Il backend serve l'app su `/` e le API su `/api`: stessa origine, niente CORS, nel frontend basta chiamare
   `/api/...` con percorsi relativi.

Da sapere per il frontend:
- **La geolocalizzazione del browser funziona solo in HTTPS** (o su `localhost`): in produzione serve HTTPS
  (vedi Cloudflare Tunnel sotto).
- Errori: le risposte non-200 hanno sempre `{"detail": ...}`. `429` = troppe richieste (mostra un messaggio),
  `422` = input non valido (es. testo vuoto o > 200 caratteri), `404` = categoria inesistente.
- Lingua: passa `lang` (`it`/`de`) se l'utente l'ha scelta nell'interfaccia, altrimenti viene rilevata dal testo.
- Colori, nomi e istruzioni arrivano già localizzati: il frontend non deve duplicare le regole.

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
    "id": "residuo", "name": "Residuo", "bin": "Contenitore del residuo",
    "color": "#6b7280", "instructions": "Va nel residuo...", "has_points": false,
    "ref": "Art. 5, 8, 32.6"
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

### `GET /api/info?lang=it` – fonte delle regole e note generali
```json
{ "municipality": "Bolzano", "source": "Regolamento gestione rifiuti - Città di Bolzano / ...",
  "notes": [{ "id": "abbandono", "text": "È vietato abbandonare rifiuti ... multa da 200 a 600 € ...", "ref": "Art. 32.5, 36" }] }
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

## Deploy su Raspberry Pi

Requisiti: Raspberry Pi OS **Bookworm o più recente** (serve Python ≥ 3.11), Pi 4/5 a 64 bit.

```bash
# 1. Copia la cartella backend sul Raspberry (es. in ~/trashy/backend), senza .venv e .env
sudo apt install -y python3-venv
cd ~/trashy/backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt

# 2. Configurazione
cp .env.example .env
nano .env                     # CORS_ORIGINS, DOCS_ENABLED=false, AI, FRONTEND_DIR...
chmod 600 .env                # contiene la chiave API

# 3. Dati
.venv/bin/python -m scripts.import_osm

# 4. Servizi (sostituisci TUOUTENTE nei file con il tuo utente)
sed -i "s/TUOUTENTE/$USER/g" deploy/*.service
sudo cp deploy/trashy.service deploy/trashy-osm.service deploy/trashy-osm.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now trashy trashy-osm.timer

# Controllo
curl http://127.0.0.1:8000/api/health
journalctl -u trashy -f       # log
```

- `trashy.service` avvia l'API all'accensione e la riavvia se si blocca (1 worker, su `127.0.0.1:8000`).
- `trashy-osm.timer` aggiorna i punti di raccolta ogni lunedì alle 4:00.
- Dopo una modifica al codice o al `.env`: `sudo systemctl restart trashy`.

### Pubblicarlo su Internet con HTTPS: Cloudflare Tunnel (consigliato)

Niente porte da aprire sul router, HTTPS automatico (necessario per la geolocalizzazione) e IP di casa nascosto.
Serve un dominio gestito su Cloudflare (account gratuito).
```bash
# installa cloudflared seguendo la guida ufficiale per Debian/Raspberry Pi, poi:
cloudflared tunnel login
cloudflared tunnel create trashy
cloudflared tunnel route dns trashy trashy.tuodominio.it
cloudflared tunnel run --url http://127.0.0.1:8000 trashy   # prova
# per avviarlo in automatico: sudo cloudflared service install (vedi guida Cloudflare)
```
Poi nel `.env`: `CORS_ORIGINS=https://trashy.tuodominio.it` e `DOCS_ENABLED=false`.
Il servizio è già avviato con `--proxy-headers --forwarded-allow-ips=127.0.0.1`, così il rate limit vede
l'IP reale degli utenti e non quello del tunnel.

Solo rete di casa (senza Internet): in `trashy.service` cambia `--host 127.0.0.1` in `--host 0.0.0.0` e
apri `http://<ip-del-raspberry>:8000`. Senza HTTPS però la geolocalizzazione del telefono non funziona.

### Ollama sullo stesso Raspberry
Un Pi 5 da 8 GB regge modelli piccoli (es. `qwen2.5:1.5b` o `3b`), ma le risposte possono richiedere
diversi secondi: imposta `AI_TIMEOUT=60` e lascia `AI_FIRST=false` così l'LLM interviene solo quando le regex
non bastano.

## Regole

`data/rules_bolzano.json` si basa sul **Regolamento gestione rifiuti della Città di Bolzano** (PDF nella cartella del progetto).
Ogni categoria ha `ref` con l'articolo di riferimento; `ref: null` = voce non trattata dal regolamento (es. abiti usati),
da verificare con SEAB. Anche alcuni singoli oggetti non sono citati nel regolamento (capsule del caffè, Tetra Pak) e sono stati
assegnati al residuo: verificarli con SEAB.
`notes` contiene regole generali mostrate da `/api/info` (solo residenti, multe per abbandono, contenitore pieno).
I `patterns` sono regex applicate al testo in minuscolo, senza accenti e senza umlaut (`Kühlschrank` → `kuhlschrank`). Se più pattern corrispondono vince il match più lungo.
Per aggiungere un altro comune basta creare un nuovo JSON e impostare `RULES_FILE`.
