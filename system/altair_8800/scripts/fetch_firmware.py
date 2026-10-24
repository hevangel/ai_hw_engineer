#!/usr/bin/env python3
"""Fetch the original MITS 4K BASIC 3.2 tape; verify its SHA-256; cache in work/.

The tape is copyrighted Microsoft/MITS software and is never committed to
Git; it is downloaded from Mike Douglas's deramp.com archive at verification
and run time. The download target is a compile-time constant validated
against an explicit scheme/host allowlist before any request is made.
"""
import hashlib
import urllib.parse
import urllib.request
from pathlib import Path

URL = ("https://deramp.com/downloads/altair/software/papertape_cassette/"
       "4K%20BASIC%20Ver%203-2.tap")
SHA256 = "fd01fd8b5c3dfbf67709809a1da6409ff1e0cb9c108fbe6a5129f8ad8e68d90f"
ALLOWED_SCHEMES = {"https"}
ALLOWED_HOSTS = {"deramp.com", "www.deramp.com"}


def validate(url):
    parts = urllib.parse.urlsplit(url)
    if parts.scheme not in ALLOWED_SCHEMES or parts.hostname not in ALLOWED_HOSTS:
        raise SystemExit(f"download target rejected by allowlist: {url}")
    return parts


def fetch(url):
    validate(url)
    request = urllib.request.Request(url, headers={"User-Agent": "ai-hw-engineer"})
    with urllib.request.urlopen(request, timeout=180) as response:
        return response.read()


def main():
    work = Path(__file__).resolve().parents[1] / "work"
    work.mkdir(exist_ok=True)
    target = work / "4kbas32.tap"
    if target.exists():
        data = target.read_bytes()
    else:
        print(f"Fetching {URL}")
        data = fetch(URL)
        target.write_bytes(data)
    digest = hashlib.sha256(data).hexdigest()
    if digest != SHA256:
        target.unlink(missing_ok=True)
        raise SystemExit(f"4K BASIC tape hash mismatch: {digest}")
    print(f"4K BASIC 3.2 tape verified: {len(data)} bytes, sha256 {digest}")


if __name__ == "__main__":
    main()
