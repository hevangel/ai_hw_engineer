#!/usr/bin/env python3
"""Command-line interface (CLI) and REPL for the Busicom 141-PF virtual platform."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# Support running directly (`python3 host/panel_cli.py`) or as a module.
_HOST_DIR = Path(__file__).resolve().parent
if str(_HOST_DIR) not in sys.path:
    sys.path.insert(0, str(_HOST_DIR))

from panel_client import (  # noqa: E402
    DEFAULT_URL,
    KEY_CODES,
    PRECISION_VALUES,
    ROUNDING_LABELS,
    PanelClient,
    format_paper_row,
)


def _format_lamps(lamps: dict[str, Any]) -> str:
    active = [
        name
        for key, name in (("overflow", "OVF"), ("negative", "NEG"), ("memory", "M"))
        if lamps.get(key)
    ]
    return " ".join(active) if active else "none"


def render_status_text(state: dict[str, Any], use_color: bool = False) -> str:
    """Format a human-readable snapshot of the calculator state and paper tape."""
    red_on = "\033[31m" if use_color else ""
    reset = "\033[0m" if use_color else ""

    ready = bool(state.get("ready"))
    busy = bool(state.get("busy"))
    status_word = "STARTING" if not ready else ("BUSY" if busy else "READY")
    precision = state.get("precision", 0)
    rounding = ROUNDING_LABELS.get(state.get("rounding", 0), str(state.get("rounding")))
    lamps = _format_lamps(state.get("lamps", {}))
    drum_pos = state.get("drumPos", 0)
    clock_hz = state.get("clockHz", 740000)

    lines = [
        f"BUSICOM 141-PF [{status_word}]  DP={precision}  ROUND={rounding}  "
        f"LAMPS={lamps}  DRUM={drum_pos + 1}/13 ({clock_hz // 1000} kHz)",
        "+" + "-" * 20 + "+",
    ]
    for row in state.get("paper", []):
        text, is_red = format_paper_row(row)
        padded = f"{text:<18}"
        if is_red and text:
            lines.append(f"| {red_on}{padded}{reset} | R")
        else:
            lines.append(f"| {padded} |")
    lines.append("+" + "-" * 20 + "+")
    return "\n".join(lines)


def _cmd_status(client: PanelClient, args: argparse.Namespace) -> int:
    st = client.wait_idle() if args.wait else client.state()
    if args.json:
        print(json.dumps(st, indent=2))
    else:
        print(render_status_text(st, use_color=sys.stdout.isatty()))
    return 0


def _cmd_press(client: PanelClient, args: argparse.Namespace) -> int:
    if not args.no_wait:
        client.wait_idle()
    expr = " ".join(args.keys)
    st = client.press_sequence(expr, wait=not args.no_wait)
    if args.json:
        print(json.dumps(st, indent=2))
    else:
        print(render_status_text(st, use_color=sys.stdout.isatty()))
    return 0


def _cmd_advance(client: PanelClient, args: argparse.Namespace) -> int:
    if not args.no_wait:
        client.wait_idle()
    st = client.advance(wait=not args.no_wait)
    if args.json:
        print(json.dumps(st, indent=2))
    else:
        print(render_status_text(st, use_color=sys.stdout.isatty()))
    return 0


def _cmd_switches(client: PanelClient, args: argparse.Namespace) -> int:
    if args.precision is None and args.rounding is None:
        raise ValueError("Specify --precision and/or --rounding")
    res = client.set_switches(precision=args.precision, rounding=args.rounding)
    if args.json:
        print(json.dumps(res, indent=2))
    else:
        st = client.state()
        print(render_status_text(st, use_color=sys.stdout.isatty()))
    return 0


def _print_repl_help() -> None:
    print(
        "Commands:\n"
        "  <keys>          Press key sequence, e.g. `C 5 + 6 + =` or `C14+29+=`\n"
        "  :dp <0..6|8>    Set decimal point selector\n"
        "  :round <mode>   Set rounding: fl (0), 5/4 (1), trunc (8)\n"
        "  :adv            Advance paper tape\n"
        "  :state          Show current status and paper tape\n"
        "  :keys           List all supported key names\n"
        "  :help           Show this help\n"
        "  :quit           Exit REPL"
    )


def _cmd_repl(client: PanelClient, args: argparse.Namespace) -> int:
    use_color = sys.stdout.isatty()
    print(f"Connecting to Busicom 141-PF at {client.url} (waiting for ready)...")
    st = client.wait_idle()
    print(render_status_text(st, use_color=use_color))
    print("Type key sequences (e.g. `C 5 + 6 + =`), `:help` for commands, `:quit` to exit.")

    while True:
        try:
            line = input("141-PF> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if not line:
            continue
        if line in (":q", ":quit", ":exit", "quit", "exit"):
            break
        if line in (":h", ":help", "?"):
            _print_repl_help()
            continue
        if line == ":keys":
            print("Keys:", " ".join(sorted(KEY_CODES.keys())))
            continue
        if line in (":s", ":state", ":status"):
            print(render_status_text(client.state(), use_color=use_color))
            continue
        if line in (":adv", ":feed"):
            st = client.advance(wait=True)
            print(render_status_text(st, use_color=use_color))
            continue
        if line.startswith(":dp "):
            try:
                val = int(line.split(None, 1)[1])
                client.set_switches(precision=val)
                print(f"Decimal point set to {val}")
            except Exception as exc:
                print(f"Error: {exc}", file=sys.stderr)
            continue
        if line.startswith(":round "):
            try:
                val = line.split(None, 1)[1]
                client.set_switches(rounding=val)
                print(f"Rounding set to {val}")
            except Exception as exc:
                print(f"Error: {exc}", file=sys.stderr)
            continue
        if line.startswith(":"):
            print(f"Unknown command {line!r}. Type :help for commands.", file=sys.stderr)
            continue

        try:
            st = client.press_sequence(line, wait=True)
            print(render_status_text(st, use_color=use_color))
        except Exception as exc:
            print(f"Error: {exc}", file=sys.stderr)
    return 0


def _cmd_tui(client: PanelClient, args: argparse.Namespace) -> int:
    from panel_tui import run_tui

    return run_tui(client.url, timeout=args.timeout)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="panel_cli.py",
        description="CLI and TUI front end for the Busicom 141-PF 4004 simulator.",
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
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit raw JSON output where applicable",
    )

    sub = parser.add_subparsers(dest="command", required=True)

    p_status = sub.add_parser("status", help="Show current panel state and paper tape")
    p_status.add_argument("--wait", action="store_true", help="Wait until simulator is ready and idle")
    p_status.set_defaults(func=_cmd_status)

    p_press = sub.add_parser("press", help="Press one or more keys (e.g. 'C 5 + 6 + =')")
    p_press.add_argument("keys", nargs="+", help="Key tokens or compact expression")
    p_press.add_argument("--no-wait", action="store_true", help="Do not wait for idle")
    p_press.set_defaults(func=_cmd_press)

    p_adv = sub.add_parser("advance", aliases=["feed"], help="Advance paper tape")
    p_adv.add_argument("--no-wait", action="store_true", help="Do not wait for idle")
    p_adv.set_defaults(func=_cmd_advance)

    p_sw = sub.add_parser("switches", help="Set decimal-point and/or rounding switches")
    p_sw.add_argument(
        "-p",
        "--precision",
        type=int,
        choices=PRECISION_VALUES,
        help="Decimal-point selector position",
    )
    p_sw.add_argument(
        "-r",
        "--rounding",
        help="Rounding mode: fl (0), 5/4 (1), or trunc (8)",
    )
    p_sw.set_defaults(func=_cmd_switches)

    p_repl = sub.add_parser("repl", help="Interactive line-oriented CLI prompt")
    p_repl.set_defaults(func=_cmd_repl)

    p_tui = sub.add_parser("tui", help="Full-screen interactive TUI")
    p_tui.set_defaults(func=_cmd_tui)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    client = PanelClient(args.url, timeout=args.timeout)
    try:
        return args.func(client, args)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
