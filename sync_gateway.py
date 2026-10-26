"""Sync between the internal Army server and the public gateway.

Runs on the internal server and always connects *outwards* to the gateway;
the gateway can never reach in. One run:

1. collects new civilian reports, stores them (linker/civil.py), then tells
   the gateway they are collected, so it wipes their text, position and photo;
2. sends back status changes made by commanders;
3. sends the current list of active warnings.

Run it every minute or so (cron or a systemd timer):
    SIRENS_GW_URL=https://gateway.example SIRENS_GW_SYNC_KEY=... python sync_gateway.py
"""
from __future__ import annotations

import base64
import json
import os
import sys
import urllib.request

from linker import civil


class HttpTransport:
    """Calls the gateway over HTTPS with the shared sync key."""

    def __init__(self, base_url: str, key: str, timeout: float = 20):
        self.base, self.key, self.timeout = base_url.rstrip("/"), key, timeout

    def __call__(self, method: str, path: str, payload: dict | None = None) -> dict:
        data = json.dumps(payload).encode() if payload is not None else None
        req = urllib.request.Request(
            self.base + "/gw/v1/sync" + path, data=data, method=method,
            headers={"X-Sync-Key": self.key, "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=self.timeout) as resp:
            return json.loads(resp.read() or b"{}")


def run_once(transport, db_path=None, batch: int = 50) -> dict:
    """One sync pass. ``transport(method, path, payload) -> dict``."""
    pulled = 0
    while True:
        reports = transport("GET", f"/reports?limit={batch}").get("reports", [])
        if not reports:
            break
        for r in reports:
            if r.get("photo"):
                r["photo"] = base64.b64decode(r["photo"])
            civil.receive(r, db_path=db_path)
        # Only acknowledged once safely stored here.
        transport("POST", "/ack", {"ids": [r["id"] for r in reports]})
        pulled += len(reports)
        if len(reports) < batch:
            break

    updates = civil.unsynced_statuses(db_path=db_path)
    if updates:
        done = set(transport("POST", "/status", {"updates": updates}).get("updated", []))
        civil.mark_statuses_synced([u for u in updates if u["id"] in done], db_path=db_path)

    sent = transport("PUT", "/warnings",
                     {"warnings": civil.public_warnings(db_path=db_path)})
    return {"reports_pulled": pulled, "statuses_sent": len(updates),
            "warnings_sent": sent.get("count", 0)}


def main() -> int:
    url, key = os.environ.get("SIRENS_GW_URL"), os.environ.get("SIRENS_GW_SYNC_KEY")
    if not url or not key:
        print("Set SIRENS_GW_URL and SIRENS_GW_SYNC_KEY.", file=sys.stderr)
        return 2
    print(json.dumps(run_once(HttpTransport(url, key))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
