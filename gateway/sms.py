"""Sending the sign-in code by SMS.

The Army chooses the SMS provider. Until then the ``console`` sender writes
the code to the server log, which is only for development and testing; the
gateway refuses to start with it unless SIRENS_GW_DEV=1 is set.
"""
from __future__ import annotations

import logging

log = logging.getLogger("sirens.gateway.sms")


class ConsoleSender:
    """Development only: logs the code instead of sending it."""
    name = "console"

    def __init__(self):
        self.sent: list[tuple[str, str]] = []   # (phone, code), read by tests

    def send_code(self, phone: str, code: str, lang: str) -> None:
        self.sent.append((phone, code))
        log.warning("DEV SMS to %s: Sirens code %s", phone, code)


class HttpSender:
    """Placeholder for the Army's SMS provider (a simple HTTP API).

    Fill in once the provider is chosen; kept here so the rest of the gateway
    does not change.
    """
    name = "http"

    def __init__(self, url: str, api_key: str):
        self.url, self.api_key = url, api_key

    def send_code(self, phone: str, code: str, lang: str) -> None:  # pragma: no cover
        raise NotImplementedError("SMS provider not configured yet")


MESSAGES = {
    "ar": "رمز الدخول إلى Sirens: {code}. لا تشاركه مع أحد.",
    "en": "Your Sirens code is {code}. Do not share it.",
    "fr": "Votre code Sirens est {code}. Ne le partagez pas.",
}
