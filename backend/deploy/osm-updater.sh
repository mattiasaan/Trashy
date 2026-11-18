#!/bin/sh
# Aggiorna i punti di raccolta da OpenStreetMap al primo avvio e poi ogni OSM_UPDATE_DAYS giorni.
# Gira nel container "osm-updater". L'ultimo import riuscito è segnato dal file MARKER nel volume,
# quindi un riavvio del Raspberry non riscarica i dati se sono ancora recenti.
MARKER=/data/.osm_last_import
DAYS=${OSM_UPDATE_DAYS:-7}

while true; do
    if [ ! -f "$MARKER" ] || [ -n "$(find "$MARKER" -mtime +$((DAYS - 1)))" ]; then
        echo "$(date '+%F %T') Aggiorno i punti OSM..."
        if python -m scripts.import_osm; then
            touch "$MARKER"
        else
            echo "$(date '+%F %T') Import fallito, riprovo tra un'ora"
            sleep 3600
            continue
        fi
    fi
    sleep 21600  # ricontrolla ogni 6 ore
done
