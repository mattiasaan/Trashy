# Trashy API

Base URL in locale: `http://localhost:8000`. Tutte le risposte sono in JSON.

Il parametro `lang` accetta `it` (default) o `de`.

## Indice

| Metodo | Endpoint | A cosa serve | Rate limit |
|---|---|---|---|
| GET | `/api/health` | Stato del server | no |
| GET | `/api/info` | Fonte delle regole e note generali | no |
| GET | `/api/categories` | Elenco delle categorie di rifiuto | no |
| GET | `/api/categories/{category_id}` | Una singola categoria | no |
| POST | `/api/ask` | Dove si butta un oggetto (domanda in testo libero) | 20/min per IP |
| GET | `/api/points` | Punti di raccolta vicini a una posizione | 60/min per IP |

Se superi il rate limit ricevi **429** `{"detail": "Troppe richieste, ..."}`.

---

## GET `/api/health`

Stato del server.

**Input:** nessuno.

**Output:**
```json
{ "status": "ok", "municipality": "Bolzano", "points_count": 412 }
```

---

## GET `/api/info`

Fonte delle regole e note generali (residenza, multe per abbandono, ...).

**Input (query):**

| Parametro | Tipo | Obbligatorio | Default |
|---|---|---|---|
| `lang` | `it` \| `de` | no | `it` |

**Output:**
```json
{
  "municipality": "Bolzano",
  "source": "https://...",
  "map_attribution": "© OpenStreetMap contributors",
  "notes": [
    { "id": "multe", "text": "...", "ref": "Art. 30" }
  ]
}
```
`map_attribution` va mostrato sulla mappa, perché la licenza ODbL di OpenStreetMap lo richiede.

---

## GET `/api/categories`

Elenco di tutte le categorie di rifiuto.

**Input (query):** `lang` (`it` | `de`, default `it`).

**Output:** una lista di oggetti **Category**:
```json
[
  {
    "id": "vetro_metallo",
    "name": "Vetro e metallo",
    "bin": "Campana blu",
    "color": "#1E88E5",
    "instructions": "Bottiglie e vasetti svuotati...",
    "has_points": true,
    "ref": "Art. 16"
  }
]
```

| Campo | Significato |
|---|---|
| `id` | Identificativo da usare negli altri endpoint |
| `name`, `bin`, `instructions` | Testi nella lingua richiesta |
| `color` | Colore esadecimale da usare nella UI |
| `has_points` | `false` se la raccolta è porta a porta, quindi senza punti sulla mappa |
| `ref` | Articolo del regolamento comunale (può essere `null`) |

Id disponibili: `residuo`, `organico`, `carta`, `vetro_metallo`, `plastica`, `raee`, `pile`, `farmaci`, `ingombranti`, `inerti`, `pericolosi`, `olio`, `abiti`, `verde`.

---

## GET `/api/categories/{category_id}`

Restituisce una sola categoria.

**Input:**
- path: `category_id`, ad es. `carta`
- query: `lang` (`it` | `de`, default `it`)

**Output:** un oggetto **Category** (vedi sopra).

**Errori:** **404** `{"detail": "Categoria non trovata"}`.

---

## POST `/api/ask`

Risponde a una domanda come "dove butto X?". Il server prova prima le regex; l'AI interviene solo se è attiva e le regex non trovano nulla. Se passi anche la posizione, la risposta include i punti di raccolta vicini.

**Input (body JSON):**

| Campo | Tipo | Obbligatorio | Default | Vincoli |
|---|---|---|---|---|
| `text` | string | **sì** | — | 1–200 caratteri |
| `lang` | `it` \| `de` | no | rilevata dal testo | |
| `lat` | float | no | — | da -90 a 90 |
| `lon` | float | no | — | da -180 a 180 |
| `radius_m` | int | no | 3000 | da 100 a 50000 |

I punti vicini vengono restituiti solo se invii **sia** `lat` **sia** `lon`.

```json
{ "text": "Dove butto le capsule del caffè?", "lat": 46.498, "lon": 11.354 }
```

**Output (oggetto riconosciuto):**
```json
{
  "lang": "it",
  "found": true,
  "source": "regex",
  "item": "capsule del caffè",
  "category": { "id": "residuo", "name": "...", "bin": "...", "color": "...", "instructions": "...", "has_points": false, "ref": "..." },
  "answer": "Residuo: ...",
  "points": []
}
```

**Output (oggetto non riconosciuto):**
```json
{
  "lang": "it", "found": false, "source": "ai",
  "item": null, "category": null,
  "answer": "Non ho capito di che rifiuto si tratta...",
  "points": null
}
```

| Campo | Significato |
|---|---|
| `found` | `false` se l'oggetto non è stato riconosciuto |
| `source` | `regex` oppure `ai`: indica chi ha classificato l'oggetto |
| `item` | Nome dell'oggetto riconosciuto (può essere `null`) |
| `answer` | Testo pronto da mostrare all'utente |
| `points` | `null` se non hai inviato `lat`/`lon`. Altrimenti al massimo 10 **Point** della categoria, ordinati per distanza |

**Errori:** **422** se l'input non è valido, **429** se superi il rate limit.

---

## GET `/api/points`

Punti di raccolta vicini a una posizione, ordinati per distanza.

**Input (query):**

| Parametro | Tipo | Obbligatorio | Default | Vincoli |
|---|---|---|---|---|
| `lat` | float | **sì** | — | da -90 a 90 |
| `lon` | float | **sì** | — | da -180 a 180 |
| `radius_m` | int | no | 3000 | da 100 a 50000 |
| `category` | string | no | — | id di una categoria |
| `kind` | `container` \| `centre` \| `pharmacy` | no | — | |
| `limit` | int | no | 20 | da 1 a 200 |

Esempio: `/api/points?lat=46.498&lon=11.354&category=pile&limit=5`

**Output:** una lista di oggetti **Point**:
```json
[
  {
    "id": "node/123456",
    "lat": 46.4991,
    "lon": 11.3562,
    "kind": "centre",
    "name": "Centro di riciclaggio ...",
    "materials": ["batteries", "paper"],
    "opening_hours": "Mo-Fr 08:00-12:00",
    "address": "Via ..., 1",
    "distance_m": 240
  }
]
```

Le categorie con raccolta porta a porta (`residuo`, `organico`) restituiscono sempre `[]`.

**Errori:** **404** se la categoria non esiste, **422** se l'input non è valido, **429** se superi il rate limit.
