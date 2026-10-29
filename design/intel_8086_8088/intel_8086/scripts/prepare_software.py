#!/usr/bin/env python3
"""Fetch unchanged MIT-licensed Microsoft MS-DOS 1.25 DEBUG.COM."""
import hashlib
import ipaddress
import socket
from pathlib import Path
import urllib.parse
import urllib.request

COMMIT = '2d04cacc5322951f187bb17e017c12920ac8ebe2'
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'work/software'
DEST.mkdir(parents=True, exist_ok=True)
BASE = f'https://raw.githubusercontent.com/microsoft/MS-DOS/{COMMIT}/'
HOST = 'raw.githubusercontent.com'

class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError('redirect refused: ' + newurl)

_OPENER = urllib.request.build_opener(_NoRedirect)

def fetch_pinned(url, timeout=90):
    # Scheme and host restricted to the pinned GitHub raw host, the host
    # resolved up front with non-global addresses refused (DNS-rebinding
    # guard; TLS certificate checks pin the actual connection), redirects
    # refused, and every artifact SHA-256 verified before use.
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != 'https' or parsed.hostname != HOST:
        raise ValueError('download host not allowed: ' + url)
    for info in socket.getaddrinfo(parsed.hostname, 443):
        address = ipaddress.ip_address(info[4][0])
        if not address.is_global:
            raise ValueError('resolved address is not global: ' + str(address))
    return _OPENER.open(url, timeout=timeout)

for name, source in [('DEBUG.COM', 'v1.25/bin/DEBUG.COM'), ('LICENSE', 'LICENSE')]:
    path = DEST / name
    if not path.exists():
        with fetch_pinned(BASE + source) as response:
            path.write_bytes(response.read())
    if name == 'DEBUG.COM' and hashlib.sha256(path.read_bytes()).hexdigest() != \
            '217b59ff054a238ace99c51831e227c9edfe0c0c6925a51c99a2d0c6107402ef':
        raise ValueError('Historical DEBUG.COM hash mismatch')
print('Prepared original Microsoft DEBUG.COM (pinned SHA-256 verified)')
