# Immagine del backend Trashy (funziona su Raspberry Pi 4/5 con OS a 64 bit e su PC x86).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Prima solo le dipendenze: se cambia solo il codice la build riusa questo strato
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app ./app
COPY scripts ./scripts
COPY data ./data
COPY deploy/osm-updater.sh /usr/local/bin/osm-updater

# sed: toglie eventuali fine riga Windows (CRLF) dallo script
RUN sed -i 's/\r$//' /usr/local/bin/osm-updater \
    && chmod +x /usr/local/bin/osm-updater \
    && useradd --uid 1000 --create-home trashy \
    && mkdir /data && chown trashy:trashy /data

USER trashy

# Il database dei punti OSM sta in un volume, così sopravvive a riavvii e aggiornamenti
ENV DB_FILE=/data/trashy.db
VOLUME /data

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health', timeout=4)"

# 1 solo worker: rate limit e tetto AI sono in memoria
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
