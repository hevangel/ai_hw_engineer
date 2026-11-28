#!/usr/bin/env python3
"""Interactive full-screen TUI for the Busicom 141-PF 4004 simulator."""

from __future__ import annotations

import argparse
import os
import queue
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

_HOST_DIR = Path(__file__).resolve().parent
if str(_HOST_DIR) not in sys.path:
    sys.path.insert(0, str(_HOST_DIR))

from panel_client import (  # noqa: E402
    DEFAULT_URL,
    PRECISION_VALUES,
    ROUNDING_LABELS,
    PanelClient,
    format_paper_row,
    parse_key_sequence,
)


@dataclass
class TuiState:
    """Mutable UI state shared between renderer and input handler."""

    connected: bool = False
    error: str = ""
    last_key: str = ""
    show_mechanism: bool = False
    show_help: bool = False
    scroll_offset: int = 0
    command_mode: bool = False
    command_buf: str = ""
    status_msg: str = "Ready. Press keys or ':' for command, '?' for help, 'Q' to quit."
    last_strike_summary: str = "Waiting for a print strike"


def format_last_strike(state: dict[str, Any], prev_ids: list[int]) -> tuple[str | None, list[int]]:
    """Detect newly observed hammer strikes from state['strikes']."""
    strikes = state.get("strikes", [])
    newest: list[tuple[int, dict[str, Any]]] = []
    next_ids = list(prev_ids)
    for idx, strike in enumerate(strikes[:18]):
        sid = int(strike.get("id", 0))
        if sid > next_ids[idx]:
            newest.append((idx + 1, strike))
            next_ids[idx] = sid
    if not newest:
        return None, next_ids
    col, last = newest[-1]
    ribbon = "red" if last.get("red") else "black"
    return f"Last strike: {last.get('char', '')} · col {col} · {ribbon} ribbon", next_ids


def render_lines(
    sim_state: dict[str, Any] | None,
    history: list[tuple[int, str, bool]],
    ui: TuiState,
    width: int = 78,
    height: int = 24,
) -> list[tuple[str, str]]:
    """Build styled (text, style_tag) lines for the TUI screen.

    Tags: 'header', 'normal', 'red', 'busy', 'ok', 'dim', 'accent', 'lamp_on'.
    """
    lines: list[tuple[str, str]] = []
    w = max(54, width)

    if sim_state and ui.connected:
        ready = bool(sim_state.get("ready"))
        busy = bool(sim_state.get("busy"))
        conn = "STARTING 4004..." if not ready else ("4004 WORKING..." if busy else "ONLINE")
        conn_tag = "busy" if (not ready or busy) else "ok"
        clock_khz = sim_state.get("clockHz", 740000) // 1000
        sector = int(sim_state.get("drumPos", 0)) + 1
        header = f" BUSICOM 141-PF   [{conn}]   {clock_khz} kHz · sector {sector}/13"
    else:
        conn_tag = "red"
        err = f" ({ui.error})" if ui.error else ""
        header = f" BUSICOM 141-PF   [OFFLINE{err}]"
    lines.append((header[:w].ljust(w), "header"))

    # Status & switches bar
    st = sim_state or {}
    lamps = st.get("lamps", {})
    ovf = "[OVF]" if lamps.get("overflow") else " ovf "
    neg = "[NEG]" if lamps.get("negative") else " neg "
    mem = "[ M ]" if lamps.get("memory") else "  m  "
    dp = st.get("precision", 0)
    rnd = ROUNDING_LABELS.get(st.get("rounding", 0), "FL")
    lines.append(
        (f" Lamps: {ovf} {neg} {mem}   |   DP ([/]): {dp}   |   Round (r): {rnd}", "accent")
    )

    # Paper tape area
    reserved_rows = 12 + (4 if ui.show_mechanism else 0)
    tape_rows = max(5, min(14, height - reserved_rows))
    lines.append((" +---- PAPER TAPE ----+   Keys: [0-9 . + - * / = %]  # :ST  Space:Feed", "dim"))

    tape_source: list[tuple[str, bool]] = []
    if history:
        tape_source = [(text, red) for _, text, red in history]
    elif st.get("paper"):
        tape_source = [format_paper_row(r) for r in st["paper"]]

    total = len(tape_source)
    max_scroll = max(0, total - tape_rows)
    scroll = min(ui.scroll_offset, max_scroll)
    end_idx = total - scroll
    start_idx = max(0, end_idx - tape_rows)
    visible = tape_source[start_idx:end_idx]

    # Pad top if fewer lines than tape_rows
    pad_count = tape_rows - len(visible)
    visible_padded = [("", False)] * pad_count + visible

    keypad_side = [
        "  c:C    e:CE   x:EX   s:Sign",
        "  7  8  9   -    # :ST  q:SQRT",
        "  4  5  6   +    /      %",
        "  1  2  3   *    = (Enter)",
        "  0  d:00   .    Space:Feed",
        "  :cm CM  :rm RM  :m+ M+  :m- M-",
        "  :m=+ M=+       :m=- M=-",
    ]
    for i, (text, is_red) in enumerate(visible_padded):
        cell = f"{text[:18]:<18}"
        mark = "R" if (is_red and text) else " "
        side = keypad_side[i] if i < len(keypad_side) else ""
        row_str = f" | {cell} |{mark}{side}"
        lines.append((row_str[:w], "red" if (is_red and text) else "normal"))

    scroll_note = f" (scroll -{scroll})" if scroll > 0 else ""
    lines.append((f" +--------------------+{scroll_note}", "dim"))

    if ui.show_mechanism:
        drum_cells = st.get("drumRow", [" "] * 18)
        drum_str = "".join(f"{str(c):<2}" for c in drum_cells[:18]).rstrip()
        lines.append((f" Drum: {drum_str}"[:w], "accent"))
        lines.append((f" {ui.last_strike_summary}"[:w], "dim"))

    if ui.show_help:
        lines.append((" Help: type digits/ops directly; c=C e=CE x=EX s=Sign q=SQRT d=00 #=ST", "accent"))
        lines.append(("       [/]=DP  r=Round  m=Mechanism  Up/Down=Scroll  :=Command  Q=Quit", "accent"))

    if ui.command_mode:
        lines.append((f" :{ui.command_buf}_"[:w], "busy"))
    else:
        last_k = f"  Last key: {ui.last_key}" if ui.last_key else ""
        lines.append((f" {ui.status_msg}{last_k}"[:w], "dim"))

    return lines


class AsyncBridgeWorker:
    """Runs HTTP actions in a background thread so the TUI never freezes."""

    def __init__(self, client: PanelClient) -> None:
        self.client = client
        self.queue: queue.Queue[tuple[str, Any]] = queue.Queue()
        self.lock = threading.Lock()
        self.sim_state: dict[str, Any] | None = None
        self.connected = False
        self.error = ""
        self.stop_event = threading.Event()
        self._poll_thread = threading.Thread(target=self._poll_loop, daemon=True)
        self._action_thread = threading.Thread(target=self._action_loop, daemon=True)

    def start(self) -> None:
        self._poll_thread.start()
        self._action_thread.start()

    def stop(self) -> None:
        self.stop_event.set()
        self.queue.put(("stop", None))

    def enqueue(self, kind: str, payload: Any = None) -> None:
        self.queue.put((kind, payload))

    def snapshot(self) -> tuple[dict[str, Any] | None, list[tuple[int, str, bool]], bool, str]:
        with self.lock:
            return self.sim_state, self.client.tape_lines(), self.connected, self.error

    def _poll_loop(self) -> None:
        while not self.stop_event.is_set():
            try:
                st = self.client.state()
                with self.lock:
                    self.sim_state = st
                    self.connected = True
                    self.error = ""
                busy = bool(st.get("busy")) or not bool(st.get("ready"))
                time.sleep(0.03 if busy else 0.08)
            except Exception as exc:
                with self.lock:
                    self.connected = False
                    self.error = str(exc)
                time.sleep(0.25)

    def _action_loop(self) -> None:
        while not self.stop_event.is_set():
            kind, payload = self.queue.get()
            if kind == "stop":
                break
            try:
                if kind == "press":
                    self.client.press(payload, wait=False)
                elif kind == "sequence":
                    self.client.press_sequence(payload, wait=True)
                elif kind == "advance":
                    self.client.advance(wait=False)
                elif kind == "switches":
                    self.client.set_switches(**payload)
            except Exception as exc:
                with self.lock:
                    self.error = str(exc)


def _handle_key(
    ch: str,
    ui: TuiState,
    worker: AsyncBridgeWorker,
    sim_state: dict[str, Any] | None,
) -> bool:
    """Process one keystroke. Return False to quit."""
    if ui.command_mode:
        if ch in ("\r", "\n"):
            cmd = ui.command_buf.strip()
            ui.command_mode = False
            ui.command_buf = ""
            if cmd in ("q", "quit", "exit"):
                return False
            if cmd in ("adv", "feed"):
                worker.enqueue("advance")
                ui.status_msg = "Advancing paper..."
            elif cmd.startswith("dp "):
                try:
                    val = int(cmd.split(None, 1)[1])
                    worker.enqueue("switches", {"precision": val})
                    ui.status_msg = f"Set DP = {val}"
                except Exception as exc:
                    ui.status_msg = f"Error: {exc}"
            elif cmd.startswith("round "):
                val = cmd.split(None, 1)[1]
                worker.enqueue("switches", {"rounding": val})
                ui.status_msg = f"Set rounding = {val}"
            elif cmd:
                try:
                    keys = parse_key_sequence(cmd)
                    if keys:
                        worker.enqueue("sequence", keys)
                        ui.last_key = " ".join(keys)
                        ui.status_msg = f"Queued {len(keys)} key(s)"
                except Exception as exc:
                    ui.status_msg = f"Error: {exc}"
            return True
        if ch in ("\x1b",):
            ui.command_mode = False
            ui.command_buf = ""
            return True
        if ch in ("\x7f", "\b", "KEY_BACKSPACE"):
            ui.command_buf = ui.command_buf[:-1]
            return True
        if len(ch) == 1 and ch.isprintable():
            ui.command_buf += ch
        return True

    if ch == "Q":
        return False
    if ch == ":":
        ui.command_mode = True
        ui.command_buf = ""
        return True
    if ch == "?":
        ui.show_help = not ui.show_help
        return True
    if ch == "m":
        ui.show_mechanism = not ui.show_mechanism
        return True
    if ch == "KEY_UP":
        ui.scroll_offset += 1
        return True
    if ch == "KEY_DOWN":
        ui.scroll_offset = max(0, ui.scroll_offset - 1)
        return True
    if ch in ("[", "]") and sim_state:
        cur = sim_state.get("precision", 0)
        idx = PRECISION_VALUES.index(cur) if cur in PRECISION_VALUES else 0
        nxt = PRECISION_VALUES[(idx + (1 if ch == "]" else -1)) % len(PRECISION_VALUES)]
        worker.enqueue("switches", {"precision": nxt})
        ui.status_msg = f"Decimal point -> {nxt}"
        return True
    if ch == "r" and sim_state:
        order = (0, 1, 8)
        cur = sim_state.get("rounding", 0)
        idx = order.index(cur) if cur in order else 0
        nxt = order[(idx + 1) % len(order)]
        worker.enqueue("switches", {"rounding": nxt})
        ui.status_msg = f"Rounding -> {ROUNDING_LABELS[nxt]}"
        return True
    if ch in (" ", "f"):
        worker.enqueue("advance")
        ui.last_key = "FEED"
        ui.scroll_offset = 0
        return True

    direct_map = {
        "0": "0", "1": "1", "2": "2", "3": "3", "4": "4",
        "5": "5", "6": "6", "7": "7", "8": "8", "9": "9",
        ".": ".", "+": "+", "-": "-", "*": "*", "/": "/",
        "=": "=", "\n": "=", "\r": "=", "%": "%", "#": "ST",
        "c": "C", "e": "CE", "x": "EX", "s": "SIGN", "q": "SQRT", "d": "00",
    }
    key_name = direct_map.get(ch)
    if key_name:
        worker.enqueue("press", key_name)
        ui.last_key = key_name
        ui.scroll_offset = 0
        ui.status_msg = f"Pressed {key_name}"
    return True


def _run_curses(worker: AsyncBridgeWorker, ui: TuiState) -> int:
    import curses

    def _loop(stdscr: Any) -> int:
        try:
            curses.curs_set(0)
        except curses.error:
            pass
        stdscr.nodelay(True)
        stdscr.timeout(50)

        attr_map = {
            "header": curses.A_REVERSE | curses.A_BOLD,
            "red": curses.A_BOLD,
            "busy": curses.A_BOLD,
            "ok": curses.A_BOLD,
            "accent": curses.A_NORMAL,
            "dim": curses.A_DIM,
            "normal": curses.A_NORMAL,
        }
        if curses.has_colors():
            curses.start_color()
            try:
                curses.use_default_colors()
                bg = -1
            except curses.error:
                bg = curses.COLOR_BLACK
            curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_CYAN)
            curses.init_pair(2, curses.COLOR_RED, bg)
            curses.init_pair(3, curses.COLOR_YELLOW, bg)
            curses.init_pair(4, curses.COLOR_GREEN, bg)
            curses.init_pair(5, curses.COLOR_CYAN, bg)
            attr_map.update(
                {
                    "header": curses.color_pair(1) | curses.A_BOLD,
                    "red": curses.color_pair(2) | curses.A_BOLD,
                    "busy": curses.color_pair(3) | curses.A_BOLD,
                    "ok": curses.color_pair(4) | curses.A_BOLD,
                    "accent": curses.color_pair(5),
                }
            )
        prev_strikes = [0] * 18

        while True:
            sim_state, history, connected, error = worker.snapshot()
            ui.connected = connected
            ui.error = error
            if sim_state:
                msg, prev_strikes = format_last_strike(sim_state, prev_strikes)
                if msg:
                    ui.last_strike_summary = msg

            h, w = stdscr.getmaxyx()
            stdscr.erase()
            for row_idx, (text, tag) in enumerate(render_lines(sim_state, history, ui, w, h)):
                if row_idx >= h:
                    break
                try:
                    stdscr.addnstr(row_idx, 0, text, w - 1, attr_map.get(tag, curses.A_NORMAL))
                except curses.error:
                    pass
            stdscr.refresh()

            try:
                key = stdscr.get_wch()
            except curses.error:
                continue
            if key == curses.KEY_UP:
                ch = "KEY_UP"
            elif key == curses.KEY_DOWN:
                ch = "KEY_DOWN"
            elif key == curses.KEY_BACKSPACE:
                ch = "KEY_BACKSPACE"
            elif isinstance(key, int):
                continue
            else:
                ch = key

            if not _handle_key(ch, ui, worker, sim_state):
                break
        return 0

    return curses.wrapper(_loop)


def _enable_windows_vt_mode() -> None:
    """Enable ANSI VT100 escape processing on Windows consoles."""
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32  # type: ignore[attr-defined]
        handle = kernel32.GetStdHandle(-11)  # STD_OUTPUT_HANDLE
        mode = ctypes.c_uint32()
        if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            kernel32.SetConsoleMode(handle, mode.value | 0x0004)
    except Exception:
        pass


def _run_ansi_windows(worker: AsyncBridgeWorker, ui: TuiState) -> int:
    import msvcrt
    import shutil

    _enable_windows_vt_mode()
    ansi_map = {
        "header": "\033[1;30;46m",
        "red": "\033[1;31m",
        "busy": "\033[1;33m",
        "ok": "\033[1;32m",
        "accent": "\033[36m",
        "dim": "\033[90m",
        "normal": "\033[0m",
    }
    prev_strikes = [0] * 18
    sys.stdout.write("\033[?25l\033[2J")
    sys.stdout.flush()
    try:
        while True:
            sim_state, history, connected, error = worker.snapshot()
            ui.connected = connected
            ui.error = error
            if sim_state:
                msg, prev_strikes = format_last_strike(sim_state, prev_strikes)
                if msg:
                    ui.last_strike_summary = msg

            size = shutil.get_terminal_size((80, 24))
            lines = render_lines(sim_state, history, ui, size.columns, size.lines)
            out = ["\033[H"]
            for text, tag in lines[: size.lines]:
                out.append(f"{ansi_map.get(tag, '')}{text}\033[0m\033[K\n")
            sys.stdout.write("".join(out))
            sys.stdout.flush()

            if msvcrt.kbhit():
                ch = msvcrt.getwch()
                if ch in ("\x00", "\xe0") and msvcrt.kbhit():
                    ext = msvcrt.getwch()
                    ch = {"H": "KEY_UP", "P": "KEY_DOWN"}.get(ext, "")
                if ch and not _handle_key(ch, ui, worker, sim_state):
                    break
            time.sleep(0.05)
    finally:
        sys.stdout.write("\033[?25h\033[0m\n")
        sys.stdout.flush()
    return 0


def run_tui(url: str = DEFAULT_URL, timeout: float = 120.0) -> int:
    client = PanelClient(url, timeout=timeout)
    worker = AsyncBridgeWorker(client)
    worker.start()
    ui = TuiState()
    try:
        if os.name == "nt":
            return _run_ansi_windows(worker, ui)
        return _run_curses(worker, ui)
    except KeyboardInterrupt:
        return 0
    finally:
        worker.stop()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="panel_tui.py",
        description="Full-screen TUI for the Busicom 141-PF 4004 simulator.",
    )
    parser.add_argument(
        "--url",
        default=DEFAULT_URL,
        help=f"Panel bridge base URL (default: {DEFAULT_URL})",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=120.0,
        help="Idle wait timeout in seconds (default: 120)",
    )
    args = parser.parse_args(argv)
    return run_tui(args.url, timeout=args.timeout)


if __name__ == "__main__":
    raise SystemExit(main())
