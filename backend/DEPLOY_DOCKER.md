# Trashy su Raspberry Pi con Docker + Cloudflare Tunnel

Tre container, tutti ripartono da soli a ogni accensione del Raspberry:

| Container     | Cosa fa                                                                 |
|---------------|-------------------------------------------------------------------------|
| `api`         | Backend FastAPI su `127.0.0.1:8000` (raggiungibile solo dal Raspberry) |
| `osm-updater` | Scarica i punti di raccolta da OpenStreetMap al primo avvio e poi ogni 7 giorni |
| `cloudflared` | Cloudflare Tunnel: pubblica l'API su `https://trashy.tuodominio.it`    |

```
App Flutter ──HTTPS──> Cloudflare ──tunnel──> cloudflared ──> api:8000
```

Non serve aprire porte sul router: il tunnel è una connessione in uscita dal Raspberry.

## Requisiti

- Raspberry Pi 4 o 5 con **Raspberry Pi OS a 64 bit** (Bookworm o più recente). Con il sistema a 32 bit alcune dipendenze non si installano.
- Un dominio gestito su Cloudflare (basta l'account gratuito).
- Accesso SSH al Raspberry.

Controlla che il sistema sia a 64 bit:
```bash
uname -m        # deve stampare: aarch64
```

---

## 1. Installa Docker

```bash
sudo apt update && sudo apt full-upgrade -y
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo systemctl enable docker      # avvia Docker a ogni accensione (di solito è già attivo)
```
Esci e rientra via SSH (serve per il gruppo `docker`), poi verifica:
```bash
docker run --rm hello-world
docker compose version
```

## 2. Scarica il progetto

```bash
sudo apt install -y git
git clone https://github.com/mattiasaan/Trashy.git ~/trashy
cd ~/trashy/backend
```
Se il repository è privato, GitHub chiede un token al posto della password (GitHub → Settings → Developer settings → Personal access tokens). In alternativa copia la cartella `backend` dal PC con `scp -r backend utente@ip-del-raspberry:~/trashy/`.

## 3. Configura il backend

```bash
cp .env.example .env
nano .env
chmod 600 .env        # contiene la chiave API
```
Valori consigliati in produzione:
```ini
DOCS_ENABLED=false
LOG_LEVEL=INFO
AI_ENABLED=true            # se usi l'AI
AI_API_KEY=...             # la tua chiave
```
`DB_FILE` e `TRUST_CF_CONNECTING_IP` non servono: li imposta già `docker-compose.yml` (rispettivamente `/data/trashy.db` e `true`).

## 4. Crea il Cloudflare Tunnel

1. Vai su [one.dash.cloudflare.com](https://one.dash.cloudflare.com) → **Networks → Tunnels → Create a tunnel**.
2. Tipo **Cloudflared**, nome `trashy`.
3. Nella schermata di installazione scegli **Docker**: compare un comando tipo
   `docker run cloudflare/cloudflared:latest tunnel --no-autoupdate run --token eyJhIjoi...`.
   **Copia solo il token** (la parte lunga dopo `--token`). Non eseguire quel comando.
4. Nella sezione **Public Hostname** (nella nuova interfaccia: *Published application routes*) aggiungi:
   - Subdomain: `trashy` — Domain: `tuodominio.it`
   - Service Type: **HTTP**
   - URL: **`api:8000`**  ← il nome del container, non `localhost`
5. Salva.

Sul Raspberry salva il token:
```bash
cp tunnel.env.example tunnel.env
nano tunnel.env           # TUNNEL_TOKEN=eyJhIjoi...
chmod 600 tunnel.env
```

> Se avevi già installato `cloudflared` direttamente sul Raspberry (vecchia guida nel README), disattivalo
> per non avere due tunnel: `sudo systemctl disable --now cloudflared`.

## 5. Avvia tutto

```bash
cd ~/trashy/backend
docker compose up -d --build
```
La prima build sul Raspberry richiede qualche minuto. Poi controlla:
```bash
docker compose ps                         # api deve risultare "healthy"
curl http://127.0.0.1:8000/api/health     # dal Raspberry
docker compose logs -f osm-updater        # primo import OSM (qualche minuto), Ctrl+C per uscire
docker compose logs -f cloudflared        # deve dire "Registered tunnel connection"
```
E da fuori casa (es. dal telefono in 4G):
```
https://trashy.tuodominio.it/api/health
```
Quando l'import OSM è finito, `points_count` nella risposta è maggiore di 0.

## 6. Verifica il riavvio automatico

```bash
sudo reboot
```
Dopo un minuto circa, rientra via SSH e lancia `docker compose ps` dalla cartella `~/trashy/backend`: i tre container devono essere `Up`.
Funziona perché Docker parte all'accensione (`systemctl enable docker`) e i container hanno `restart: unless-stopped`.
Se fermi un container con `docker compose stop`, resta fermo anche dopo il riavvio finché non lo riavvii tu.

## 7. Collega l'app Flutter

Usa come URL base delle API:
```dart
const apiBaseUrl = 'https://trashy.tuodominio.it';
```
- Android: nel file `android/app/src/main/AndroidManifest.xml` serve
  `<uses-permission android:name="android.permission.INTERNET"/>` (in debug c'è già, in release no).
- Il CORS non serve per le app native: lascia `CORS_ORIGINS` vuoto (serve solo se pubblichi anche Flutter Web).

---

## Uso quotidiano

Tutti i comandi vanno lanciati da `~/trashy/backend`.

| Cosa                                   | Comando |
|----------------------------------------|---------|
| Stato dei container                    | `docker compose ps` |
| Log dell'API                           | `docker compose logs -f api` |
| Riavviare dopo aver modificato `.env`  | `docker compose up -d` |
| Aggiornare il codice                   | `git pull && docker compose up -d --build` |
| Forzare l'aggiornamento dei punti OSM  | `docker compose exec osm-updater python -m scripts.import_osm` |
| Fermare tutto                          | `docker compose down` (il database resta nel volume `trashy-db`) |
| Liberare spazio dopo molti aggiornamenti | `docker image prune -f` |

I log sono limitati a 3 file da 10 MB per container, così non riempiono la scheda SD.

## Ollama sullo stesso Raspberry (facoltativo)

Ollama installato sul Raspberry (fuori da Docker) si raggiunge dal container con `host.docker.internal`:
```ini
AI_BASE_URL=http://host.docker.internal:11434/v1
AI_API_KEY=ollama
AI_MODEL=qwen2.5:3b
AI_REASONING_EFFORT=
AI_TIMEOUT=60
```
Ollama di default ascolta solo su `127.0.0.1`, che il container non vede. Fallo ascoltare anche sulla rete Docker:
```bash
sudo systemctl edit ollama
# aggiungi:
# [Service]
# Environment="OLLAMA_HOST=0.0.0.0"
sudo systemctl restart ollama
```
Se il Raspberry è su una rete di cui non ti fidi, blocca la porta 11434 dall'esterno con il firewall.

## Problemi comuni

- **`api` resta `unhealthy` o si riavvia di continuo** → `docker compose logs api`. Di solito è un errore nel `.env`.
- **`https://trashy.tuodominio.it` dà errore 502** → il Public Hostname non punta a `api:8000`, oppure `api` non è ancora partito.
- **`cloudflared` si riavvia di continuo** → token sbagliato o incompleto in `tunnel.env`.
- **Dall'app arrivano errori 403 ma dal browser funziona** → in Cloudflare (Security → Bots) disattiva *Bot Fight Mode*: blocca le richieste che non vengono da un browser, come quelle dell'app.
- **`points_count` resta 0** → `docker compose logs osm-updater`. Se i server Overpass sono sovraccarichi, lo script riprova da solo dopo un'ora.
- **Errore 429 "Troppe richieste"** → è il rate limit per IP: alza `RATE_LIMIT_ASK` / `RATE_LIMIT_POINTS` nel `.env` e lancia `docker compose up -d`.
