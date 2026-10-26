"""Push notifications to civilians' phones (switchable).

Google (Android) and Apple (iPhone) push is not yet approved by the Army, so
the default sender is ``disabled``: nothing leaves the gateway, and the app
fetches warnings itself. A push message never carries incident details; it
only says that warnings changed and asks the user to open the app.
"""
from __future__ import annotations

import logging

log = logging.getLogger("sirens.gateway.push")


class DisabledPush:
    name = "disabled"

    def notify_warnings_changed(self, device_tokens: list[str]) -> int:
        return 0


class RecordingPush:
    """Test helper: remembers what would have been sent."""
    name = "recording"

    def __init__(self):
        self.calls: list[list[str]] = []

    def notify_warnings_changed(self, device_tokens: list[str]) -> int:
        self.calls.append(list(device_tokens))
        return len(device_tokens)
