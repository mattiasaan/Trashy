"""Scarica da OpenStreetMap (Overpass API) i punti di raccolta dell'Alto Adige e li salva in SQLite.

Uso (dalla cartella backend/):  python -m scripts.import_osm
Rilancialo quando vuoi aggiornare i dati (es. una volta a settimana).
"""
import json
import urllib.parse
import urllib.request

from app.points import connect

# Server pubblici: se il primo è sovraccarico si prova il successivo
OVERPASS_URLS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]

QUERY = """
[out:json][timeout:180];
area["ISO3166-2"="IT-BZ"]->.a;
(
  nwr["amenity"="recycling"](area.a);
  nwr["amenity"="waste_basket"](area.a);
  nwr["amenity"="pharmacy"](area.a);
);
out center tags;
"""


def fetch() -> list[dict]:
    data = urllib.parse.urlencode({"data": QUERY}).encode()
    for url in OVERPASS_URLS:
        req = urllib.request.Request(url, data=data, headers={"User-Agent": "Trashy/0.1"})
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                return json.load(resp)["elements"]
        except Exception as e:
            print(f"  {url} non disponibile: {e}")
    raise SystemExit("Nessun server Overpass disponibile, riprova più tardi.")


def to_row(el: dict) -> tuple | None:
    tags = el.get("tags", {})
    lat = el.get("lat") or el.get("center", {}).get("lat")
    lon = el.get("lon") or el.get("center", {}).get("lon")
    if lat is None or lon is None:
        return None

    if tags.get("amenity") == "pharmacy":
        kind = "pharmacy"
    elif tags.get("amenity") == "waste_basket":
        kind = "waste_basket"
    elif tags.get("recycling_type") == "centre":
        kind = "centre"
    else:
        kind = "container"

    materials = [k.split(":", 1)[1] for k, v in tags.items() if k.startswith("recycling:") and v == "yes"]
    address = " ".join(filter(None, [tags.get("addr:street"), tags.get("addr:housenumber")]))
    if tags.get("addr:city"):
        address = f"{address}, {tags['addr:city']}" if address else tags["addr:city"]

    name = tags.get("name") or tags.get("name:it") or tags.get("name:de") or tags.get("operator")
    return (
        f"{el['type']}/{el['id']}",
        lat,
        lon,
        kind,
        name,
        f",{','.join(materials)}," if materials else "",
        tags.get("opening_hours"),
        address or None,
    )


def main():
    print("Scarico i dati da Overpass (può richiedere qualche minuto)...")
    rows = [r for r in map(to_row, fetch()) if r]
    with connect() as conn:
        conn.execute("DELETE FROM points")
        conn.executemany("INSERT OR REPLACE INTO points VALUES (?,?,?,?,?,?,?,?)", rows)
    print(f"Importati {len(rows)} punti.")


if __name__ == "__main__":
    main()