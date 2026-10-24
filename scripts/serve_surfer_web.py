#!/usr/bin/env python3
"""Serve Surfer's static UI and proxy its token-scoped API to local Surver."""

from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit, unquote, urlunsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler
import os


WEB_ROOT = Path("/opt/surfer/webapp").resolve()
TOKEN = os.environ["SURFER_TOKEN"]
SURVER_ORIGIN = "http://127.0.0.1:8911"


class _NoRedirect(HTTPRedirectHandler):
    # The proxy forwards Surver's own responses only; it must never follow
    # a redirect to another origin itself.
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("redirect refused: " + newurl)


_PROXY_OPENER = build_opener(_NoRedirect)
HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
}


class SurferWebHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)

    def _static_file_exists(self):
        path = unquote(urlsplit(self.path).path)
        if path == "/":
            path = "/index.html"
        candidate = (WEB_ROOT / path.lstrip("/")).resolve()
        try:
            candidate.relative_to(WEB_ROOT)
        except ValueError:
            return False
        return candidate.is_file()

    def _is_surver_path(self):
        path = urlsplit(self.path).path
        return path == f"/{TOKEN}" or path.startswith(f"/{TOKEN}/")

    def do_GET(self):
        if self._static_file_exists():
            return super().do_GET()
        if self._is_surver_path():
            return self._proxy_to_surver()
        self.send_error(404, "Not found")

    def do_HEAD(self):
        if self._static_file_exists():
            return super().do_HEAD()
        if self._is_surver_path():
            return self._proxy_to_surver(include_body=False)
        self.send_error(404, "Not found")

    def _proxy_to_surver(self, include_body=True):
        parsed = urlsplit(self.path)
        # The only permitted upstream is the local Surver instance this
        # launcher started; validate the constructed target before opening
        # the connection, so a mangled request path can never widen it.
        target = SURVER_ORIGIN + parsed.path
        if parsed.query:
            target += "?" + parsed.query
        checked = urlsplit(target)
        if checked.scheme != "http" or checked.hostname != "127.0.0.1":
            self.send_error(400, "Refusing non-local surver target")
            return
        headers = {}
        if self.headers.get("Accept"):
            headers["Accept"] = self.headers["Accept"]
        request = Request(target, headers=headers, method="GET" if include_body else "HEAD")

        try:
            response = _PROXY_OPENER.open(request, timeout=60)
        except HTTPError as error:
            response = error
        except (URLError, TimeoutError, OSError) as error:
            self.send_error(502, f"Surver request failed: {error}")
            return

        with response:
            # Surfer's WASM client identifies a remote Surver through its
            # `Server: Surfer` response header, so preserve it verbatim.
            self.send_response_only(response.status)
            self.log_request(response.status)
            for name, value in response.headers.items():
                if name.lower() not in HOP_BY_HOP_HEADERS:
                    self.send_header(name, value)
            self.end_headers()
            if include_body:
                while chunk := response.read(1024 * 1024):
                    self.wfile.write(chunk)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 8080), SurferWebHandler)
    print("Surfer web UI and same-origin Surver proxy listening on 0.0.0.0:8080", flush=True)
    server.serve_forever()
