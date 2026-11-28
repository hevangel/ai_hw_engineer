#!/usr/bin/env python3
"""Unit tests for panel_client, panel_cli, and panel_tui against a mock bridge."""

from __future__ import annotations

import json
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any

SYSTEM_DIR = Path(__file__).resolve().parents[1]
HOST_DIR = SYSTEM_DIR / "host"
if str(HOST_DIR) not in sys.path:
    sys.path.insert(0, str(HOST_DIR))

import panel_cli  # noqa: E402
import panel_client  # noqa: E402
import panel_tui  # noqa: E402


class MockBridgeState:
    def __init__(self) -> None:
        self.precision = 0
        self.rounding = 0
        self.paper_sequence = 6
        self.pressed: list[int] = []
        self.advances = 0
        self.paper: list[list[Any]] = [[" "] * 18 + [0] for _ in range(7)]
        self.paper[6] = list("               11 ") + [0]
        self.paper[6][16] = "*"

    def as_json(self) -> dict[str, Any]:
        return {
            "lamps": {"memory": 0, "overflow": 0, "negative": 0},
            "precision": self.precision,
            "rounding": self.rounding,
            "busy": 0,
            "ready": 1,
            "drumTick": 100,
            "drumPos": 4,
            "clockHz": 740000,
            "paceLagTicks": 0,
            "drumRow": ["4"] * 15 + [" ", "M+", "M+"],
            "paper_sequence": self.paper_sequence,
            "paper": self.paper,
            "strikes": [{"id": 0, "red": 0, "char": ""} for _ in range(18)],
        }


def make_handler(bridge: MockBridgeState) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
            return

        def do_GET(self) -> None:
            if self.path == "/state.json":
                body = json.dumps(bridge.as_json()).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            elif self.path == "/empty":
                self.send_response(200)
                self.send_header("Content-Length", "0")
                self.end_headers()
            else:
                self.send_response(404)
                self.end_headers()

        def do_POST(self) -> None:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length) or b"{}")
            if self.path == "/press":
                bridge.pressed.append(int(payload["code"]))
            elif self.path == "/advance":
                bridge.advances += 1
                bridge.paper_sequence += 1
                bridge.paper = bridge.paper[1:] + [[" "] * 18 + [0]]
            elif self.path == "/switches":
                if "precision" in payload:
                    bridge.precision = int(payload["precision"])
                if "rounding" in payload:
                    bridge.rounding = int(payload["rounding"])
            else:
                self.send_response(404)
                self.end_headers()
                return
            body = b'{"ok":true}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    return Handler


class PanelCliTuiTests(unittest.TestCase):
    server: HTTPServer
    thread: threading.Thread
    bridge: MockBridgeState
    url: str

    @classmethod
    def setUpClass(cls) -> None:
        cls.bridge = MockBridgeState()
        cls.server = HTTPServer(("127.0.0.1", 0), make_handler(cls.bridge))
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self) -> None:
        self.bridge.pressed.clear()
        self.bridge.advances = 0

    def test_parse_key_sequence(self) -> None:
        self.assertEqual(
            panel_client.parse_key_sequence("C14+29+="),
            ["C", "1", "4", "+", "2", "9", "+", "="],
        )
        self.assertEqual(
            panel_client.parse_key_sequence("M=+ 500 M+ RM #"),
            ["M=+", "5", "00", "M+", "RM", "ST"],
        )
        with self.assertRaises(ValueError):
            panel_client.parse_key_sequence("Z")

    def test_loopback_enforced(self) -> None:
        with self.assertRaises(ValueError):
            panel_client.PanelClient("http://example.com:8080")

    def test_empty_response_gives_clear_error(self) -> None:
        client = panel_client.PanelClient(self.url)
        with self.assertRaises(RuntimeError) as ctx:
            client.request("/empty")
        self.assertIn("Empty response", str(ctx.exception))

    def test_cli_press_switches_advance_status(self) -> None:
        rc = panel_cli.main(["--url", self.url, "switches", "-p", "2", "-r", "5/4"])
        self.assertEqual(rc, 0)
        self.assertEqual(self.bridge.precision, 2)
        self.assertEqual(self.bridge.rounding, 1)

        rc = panel_cli.main(["--url", self.url, "press", "C 5 + 6 + ="])
        self.assertEqual(rc, 0)
        self.assertEqual(
            self.bridge.pressed,
            [160, 150, 142, 146, 142, 140],
        )

        rc = panel_cli.main(["--url", self.url, "advance"])
        self.assertEqual(rc, 0)
        self.assertEqual(self.bridge.advances, 1)

        rc = panel_cli.main(["--url", self.url, "status"])
        self.assertEqual(rc, 0)

    def test_tui_render_lines(self) -> None:
        client = panel_client.PanelClient(self.url)
        st = client.state()
        ui = panel_tui.TuiState(connected=True, show_mechanism=True, show_help=True)
        lines = panel_tui.render_lines(st, client.tape_lines(), ui, width=80, height=26)
        rendered = "\n".join(text for text, _ in lines)
        self.assertIn("BUSICOM 141-PF", rendered)
        self.assertIn("ONLINE", rendered)
        self.assertIn("PAPER TAPE", rendered)
        self.assertIn("Drum:", rendered)
        self.assertIn("Help:", rendered)


if __name__ == "__main__":
    unittest.main()
