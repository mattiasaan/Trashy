"""Prova diretta dell'AI, saltando regex e app.

Uso (dalla cartella backend/):
    python -m scripts.test_ai "dove butto il cartone della pizza?"

Usa la configurazione del .env anche se AI_ENABLED=false e stampa log dettagliati
(errore HTTP di Google, risposta grezza del modello, categoria scelta).
"""
import logging
import sys

logging.basicConfig(level=logging.DEBUG, format="%(levelname)-7s [%(name)s] %(message)s")
for noisy in ("httpx", "httpx2", "httpcore", "openai"):
    logging.getLogger(noisy).setLevel(logging.WARNING)

from app import ai, config  # noqa: E402

text = " ".join(sys.argv[1:]) or "dove butto il cartone della pizza?"
print(f"AI_ENABLED={config.AI_ENABLED} (ignorato da questo script)")
print(f"AI_BASE_URL={config.AI_BASE_URL}")
print(f"AI_MODEL={config.AI_MODEL}  AI_REASONING_EFFORT={config.AI_REASONING_EFFORT}")
print(f"AI_API_KEY={config.masked_key()}")
print(f"Testo: {text!r}\n")

result = ai.classify(text, ip="test")
print()
if result is None:
    print("FALLITO: guarda l'errore qui sopra.")
    sys.exit(1)
print(f"OK: {result}")
