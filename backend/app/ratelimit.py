"""Rate limiting semplice in memoria (finestra scorrevole per IP).

Va bene con un solo processo uvicorn (es. Raspberry Pi). Con più worker
ogni processo ha il suo contatore.
"""
import threading
import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request


class RateLimiter:
    def __init__(self, limit: int, window_s: int = 60):
        self.limit = limit
        self.window_s = window_s
        self.hits: dict[str, deque] = defaultdict(deque)
        self.lock = threading.Lock()

    def allow(self, key: str) -> bool:
        now = time.monotonic()
        with self.lock:
            if len(self.hits) > 10_000:  # evita che la memoria cresca all'infinito
                self.hits.clear()
            q = self.hits[key]
            while q and now - q[0] > self.window_s:
                q.popleft()
            if len(q) >= self.limit:
                return False
            q.append(now)
            return True

    def __call__(self, request: Request):
        """Usabile come dipendenza FastAPI: Depends(limiter)."""
        ip = request.client.host if request.client else "unknown"
        if not self.allow(ip):
            raise HTTPException(429, "Troppe richieste, riprova tra poco / Zu viele Anfragen, bitte später erneut versuchen")
