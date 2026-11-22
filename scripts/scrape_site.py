#!/usr/bin/env python3
"""Polite, resumable mirror of a single website (Python stdlib only).

Crawls one web host (plus its www alias and any --extra-host), saves every
page and asset under an output directory that mirrors the URL structure,
rewrites links inside saved HTML/CSS to root-relative paths, and downloads
every linked file (zip/pdf/ttf/...) as an asset.

Politeness:
  * honors robots.txt, including Crawl-delay and Sitemap entries
  * sleeps --delay (+ random --jitter) between every request
  * backs off on 429/503/5xx and connection errors
  * identifies itself honestly via User-Agent
  * refuses to talk to localhost, private or otherwise non-public hosts
    (DNS is resolved and every returned address is checked)

Resumability: crawl state (seen URLs, queue, URL map) is saved to the
hidden .mirror_state.json inside the output directory every 25 fetches and
on exit; rerunning the same command continues where the previous run left
off.

Path safety: every filesystem location is computed by contained_path(),
which normalizes the relative label, explicitly refuses any "." or ".."
segment, re-validates each segment through sanitize_segment() (no path
separators inside segments, no all-dot names, Windows reserved names
prefixed), and verifies with resolve().is_relative_to() that the final
path stays inside the output directory. All I/O uses pathlib methods
(read_text/write_text/write_bytes/unlink/rglob), so no raw path string
ever reaches open().

Rewritten links are root-relative, so browse the mirror with a static
server rooted at the output directory, e.g.:

    py -3 -m http.server 8080 --directory references/int10h

Usage:
    py -3 -I scripts/scrape_site.py https://int10h.org/ references/int10h \
        --delay 2 --jitter 1
"""

import argparse
import collections
import gzip
import hashlib
import html as html_mod
import http.client
import ipaddress
import io
import json
import random
import re
import socket
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import urllib.robotparser
from html.parser import HTMLParser
from pathlib import Path, PurePosixPath

USER_AGENT = (
    "ai-hw-engineer-reference-mirror/1.0 "
    "(polite personal reference crawler; slow rate; honors robots.txt)"
)

PAGE_TYPES = ("text/html", "application/xhtml+xml")

# HTML attributes that can carry URLs worth downloading or rewriting.
URL_ATTRS = ("href", "src", "srcset", "poster", "data", "action",
             "background", "cite")

ATTR_VALUE_RE = re.compile(
    r"(?P<attr>\b(?:href|src|srcset|poster|data|action|background|cite)\s*=)"
    r"(?P<quote>[\"'])(?P<value>.*?)(?P=quote)",
    re.IGNORECASE | re.DOTALL,
)

STYLE_BLOCK_RE = re.compile(
    r"(<style\b[^>]*>)(.*?)(</style\s*>)", re.IGNORECASE | re.DOTALL)
SCRIPT_BLOCK_RE = re.compile(
    r"(<script\b[^>]*>)(.*?)(</script\s*>)", re.IGNORECASE | re.DOTALL)

CSS_URL_RE = re.compile(r"url\(\s*([\"']?)([^'\")]+)\1\s*\)", re.IGNORECASE)
CSS_IMPORT_RE = re.compile(r"@import\s+([\"'])([^'\"]+)\1", re.IGNORECASE)

CHARSET_META_RE = re.compile(rb"charset\s*=\s*[\"']?([A-Za-z0-9_.:-]+)",
                             re.IGNORECASE)
CHARSET_HDR_RE = re.compile(r"charset\s*=\s*[\"']?([A-Za-z0-9_.:-]+)",
                            re.IGNORECASE)

# Characters that are unsafe in Windows/POSIX path segments.
WIN_UNSAFE_RE = re.compile(r'[<>:"/\\|?*\x00-\x1f]')
# Windows reserved device names cannot be used as file or folder names.
RESERVED_NAMES = {"con", "prn", "aux", "nul"}
RESERVED_NAMES.update(f"com{i}" for i in range(1, 10))
RESERVED_NAMES.update(f"lpt{i}" for i in range(1, 10))

MAX_SITEMAP_BYTES = 10 * 1024 * 1024
MAX_SITEMAP_DEPTH = 5

STATE_NAME = ".mirror_state.json"
FAILED_NAME = ".mirror_failed.txt"
LOG_NAME = ".mirror_log.txt"

# Cryptographically seeded RNG; used only for request-rate jitter.
RNG = random.SystemRandom()

LOG_FILE = None


def log(message):
    line = time.strftime("%H:%M:%S ") + message
    print(line, flush=True)
    if LOG_FILE is not None:
        try:
            LOG_FILE.write(line + "\n")
            LOG_FILE.flush()
        except OSError:
            pass


# --------------------------------------------------------------------------
# URL and path safety helpers
# --------------------------------------------------------------------------

def canonical_url(url):
    """Lowercase scheme/host, drop default ports and fragments."""
    sp = urllib.parse.urlsplit(url.strip())
    scheme = sp.scheme.lower()
    host = sp.netloc.lower()
    if scheme == "http" and host.endswith(":80"):
        host = host[:-3]
    if scheme == "https" and host.endswith(":443"):
        host = host[:-4]
    return urllib.parse.urlunsplit((scheme, host, sp.path, sp.query, ""))


def safe_request_url(url):
    """Percent-encode characters http.client refuses (spaces, controls).

    Pages on old sites often carry hrefs with literal spaces in the query
    or path; quoting them here keeps every queued URL fetchable while
    leaving existing percent-escapes untouched.
    """
    sp = urllib.parse.urlsplit(url)
    path = urllib.parse.quote(sp.path, safe="/%:@!$&'()*+,;=~-._")
    query = urllib.parse.quote(sp.query, safe="=&?/%:@!$'()*+,;~-._")
    return urllib.parse.urlunsplit(
        (sp.scheme, sp.netloc, path, query, sp.fragment))


def validate_host(host):
    """Resolve host; return a refusal reason if any address is non-public."""
    try:
        infos = socket.getaddrinfo(host, None)
    except OSError as exc:
        return f"DNS lookup failed: {exc}"
    for info in infos:
        ip = ipaddress.ip_address(info[4][0])
        if (ip.is_private or ip.is_loopback or ip.is_link_local
                or ip.is_reserved or ip.is_multicast or ip.is_unspecified
                or not ip.is_global):
            return f"host {host} resolves to non-public address {ip}"
    return None


def sanitize_segment(segment):
    """Make a URL path segment safe as a file/directory name.

    Separators and control characters are replaced, trailing dots/spaces are
    stripped (Windows requirement), all-dot names and empty names become "_",
    and Windows reserved device names get a prefix. The result never contains
    a path separator.
    """
    segment = WIN_UNSAFE_RE.sub("_", segment).rstrip(" .")
    if not segment or set(segment) <= {"."}:
        return "_"
    if segment.split(".")[0].lower() in RESERVED_NAMES:
        segment = "_" + segment
    return segment


def contained_path(out_dir, rel):
    """The single filesystem choke-point for this crawler.

    Normalizes the relative label, explicitly refuses any "." or ".."
    segment, re-checks every segment with sanitize_segment(), then joins
    onto the resolved output directory and verifies containment with
    resolve().is_relative_to(). Returns a pathlib.Path or raises.
    """
    base = Path(out_dir).resolve()
    parts = [p for p in str(rel).replace("\\", "/").split("/")
             if p and p != "."]
    for part in parts:
        if part == "..":
            raise ValueError(f"path segment refused: {part!r}")
        if part != sanitize_segment(part):
            raise ValueError(f"path segment not filesystem-safe: {part!r}")
    resolved = base.joinpath(*parts).resolve()
    if not resolved.is_relative_to(base):
        raise ValueError(f"path escapes output directory: {rel!r}")
    return resolved


def url_to_relpath(url):
    """Deterministic local label (relative, POSIX form) for a URL.

    Returns a plain string, never a filesystem handle; callers must route
    it through contained_path() before touching the disk (every write in
    this file does). Each segment passes sanitize_segment(), so the label
    contains no separators inside segments and cannot climb directories.
    """
    sp = urllib.parse.urlsplit(url)
    raw_segs = sp.path.split("/")
    dir_like = sp.path == "" or sp.path.endswith("/")
    segs = []
    for raw in raw_segs:
        if raw in ("", "."):
            continue
        segs.append(sanitize_segment(urllib.parse.unquote(raw)))
    if not segs:
        parts = ["index.html"]
    else:
        last = segs.pop()
        if dir_like:
            segs.append(last)
            parts = segs + ["index.html"]
        else:
            if PurePosixPath(last).suffix == "":
                last += ".html"
            parts = segs + [last]
    if sp.query:
        digest = hashlib.sha256(sp.query.encode("utf-8")).hexdigest()[:8]
        stem, dot, ext = parts[-1].rpartition(".")
        if dot:
            parts[-1] = f"{stem}_q-{digest}.{ext}"
        else:
            parts[-1] = f"{stem}_q-{digest}"
    return "/".join(parts)


def write_file(out_dir, rel, data):
    path = contained_path(out_dir, rel)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def root_relative_href(to_relpath):
    """Root-relative href text so the mirror is served from its root.

    Serve the mirror with e.g. `py -3 -m http.server --directory <out_dir>`;
    root-relative links then always resolve inside the mirror tree.
    """
    posix = to_relpath.replace("\\", "/")
    return "/" + urllib.parse.quote(posix, safe="/-._~()")


def sniff_charset(ctype_header, body):
    if ctype_header:
        m = CHARSET_HDR_RE.search(ctype_header)
        if m:
            return m.group(1)
    if body:
        m = CHARSET_META_RE.search(body[:4096])
        if m:
            return m.group(1).decode("ascii", "replace")
    return "utf-8"


def decode_text(data, charset):
    for cs in (charset, "utf-8", "windows-1252"):
        try:
            return data.decode(cs), cs
        except (LookupError, UnicodeDecodeError):
            continue
    return None, charset


def parse_retry_after(headers, default):
    if headers is not None:
        value = headers.get("Retry-After")
        if value:
            try:
                return min(max(int(value), 1), 300)
            except ValueError:
                pass
    return default


# --------------------------------------------------------------------------
# HTML link extraction
# --------------------------------------------------------------------------

class LinkExtractor(HTMLParser):
    """Collects candidate URLs and the <base href> of an HTML document."""

    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.urls = []
        self.base_href = None

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        values = dict(attrs)
        if tag == "base" and values.get("href"):
            if self.base_href is None:
                self.base_href = values["href"]
            return
        for name in URL_ATTRS:
            value = values.get(name)
            if value:
                self.urls.append(value)


# --------------------------------------------------------------------------
# The mirror crawler
# --------------------------------------------------------------------------

class SiteMirror:
    STATE_VERSION = 1

    def __init__(self, start_url, out_dir, *, delay, jitter, max_pages,
                 max_bytes, timeout, retries, fresh=False,
                 retry_failed=False, extra_hosts=()):
        self.start_url = canonical_url(start_url)
        if not self.start_url.startswith(("http://", "https://")):
            raise SystemExit(f"start URL must be http/https: {start_url}")
        self.out_dir = out_dir
        self.delay = max(delay, 0.0)
        self.jitter = max(jitter, 0.0)
        self.max_pages = max_pages
        self.max_bytes = max_bytes
        self.timeout = timeout
        self.retries = retries
        self.retry_failed = retry_failed
        self.fresh = fresh

        Path(out_dir).mkdir(parents=True, exist_ok=True)

        host = urllib.parse.urlsplit(self.start_url).netloc
        self.allowed_hosts = {host}
        if host.startswith("www."):
            self.allowed_hosts.add(host[4:])
        else:
            self.allowed_hosts.add("www." + host)
        self.allowed_hosts.update(h.lower() for h in extra_hosts)
        # Hosts we have verified speak https; plain-http links get upgraded.
        self.https_hosts = set(self.allowed_hosts)

        self.seen = {}            # canonical url -> status
        self.queue = collections.deque()
        self.urlmap = {}          # canonical url -> local relpath label
        self.counts = collections.Counter()
        self.robots_cache = {}
        self.validated_hosts = {}
        self.external_warned = set()
        self.force_http_hosts = set()

    # -- state ------------------------------------------------------------

    def seed(self):
        state_path = contained_path(self.out_dir, STATE_NAME)
        if state_path.exists() and not self.fresh:
            state = json.loads(state_path.read_text(encoding="utf-8"))
            self.seen = state.get("seen", {})
            self.queue = collections.deque(state.get("queue", []))
            self.urlmap = state.get("urlmap", {})
            self.counts.update(state.get("counts", {}))
            log(f"resumed state: {len(self.seen)} urls seen, "
                f"queued={len(self.queue)}")
        else:
            if self.fresh and state_path.exists():
                state_path.unlink()
            self.enqueue(self.start_url)
        if self.retry_failed:
            requeued = 0
            for url, status in list(self.seen.items()):
                if status not in ("done", "queued"):
                    self.seen[url] = "queued"
                    self.queue.append(url)
                    requeued += 1
            if requeued:
                log(f"requeued {requeued} previously failed URLs")

    def save_state(self):
        payload = json.dumps({
            "version": self.STATE_VERSION,
            "start_url": self.start_url,
            "seen": self.seen,
            "queue": list(self.queue),
            "urlmap": self.urlmap,
            "counts": dict(self.counts),
        })
        contained_path(self.out_dir, STATE_NAME).write_text(
            payload, encoding="utf-8")

    def write_failed_report(self):
        rows = sorted((url, status) for url, status in self.seen.items()
                      if status not in ("done", "queued"))
        lines = "".join(f"{status}\t{url}\n" for url, status in rows)
        contained_path(self.out_dir, FAILED_NAME).write_text(
            lines, encoding="utf-8")

    # -- host policy --------------------------------------------------------

    def host_blocked(self, host):
        if host not in self.validated_hosts:
            problem = validate_host(host)
            self.validated_hosts[host] = problem
            if problem:
                log(f"REFUSED host {host}: {problem}")
        return bool(self.validated_hosts[host])

    def note_external(self, host):
        if host not in self.external_warned:
            self.external_warned.add(host)
            log(f"external host skipped (not fetched): {host}")

    # -- queue ---------------------------------------------------------------

    def enqueue(self, url):
        canonical = canonical_url(url)
        sp = urllib.parse.urlsplit(canonical)
        scheme = sp.scheme.lower()
        if scheme not in ("http", "https"):
            return
        host = sp.netloc
        if host not in self.allowed_hosts:
            self.note_external(host)
            return
        if host in self.https_hosts and scheme == "http":
            canonical = "https://" + canonical[len("http://"):]
            sp = urllib.parse.urlsplit(canonical)
        if canonical in self.seen:
            return
        if self.host_blocked(sp.netloc):
            return
        self.seen[canonical] = "queued"
        self.queue.append(canonical)

    # -- robots ---------------------------------------------------------------

    def robots_for(self, url):
        netloc = urllib.parse.urlsplit(url).netloc
        if netloc in self.robots_cache:
            return self.robots_cache[netloc]
        parser = urllib.robotparser.RobotFileParser()
        robots_url = urllib.parse.urljoin(url, "/robots.txt")
        try:
            request = urllib.request.Request(
                robots_url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(
                    request, timeout=min(self.timeout, 30)) as resp:
                parser.parse(resp.read().decode(
                    "utf-8", "replace").splitlines())
            crawl_delay = parser.crawl_delay(USER_AGENT)
            delay_note = (f", crawl-delay {crawl_delay}s"
                          if crawl_delay else ", no crawl-delay set")
            log(f"robots.txt loaded from {robots_url}{delay_note}")
            if crawl_delay and float(crawl_delay) > self.delay + self.jitter:
                log(f"will honor robots crawl-delay of {crawl_delay}s "
                    f"(higher than the requested delay)")
        except Exception as exc:
            log(f"robots.txt unavailable at {robots_url} "
                f"({exc.__class__.__name__}); treating as allow-all")
            parser = None
        self.robots_cache[netloc] = parser
        time.sleep(self.effective_delay(parser))
        return parser

    def effective_delay(self, parser=None):
        """Sleep time for the next request, honoring robots Crawl-delay."""
        base = self.delay + RNG.uniform(0, self.jitter)
        for candidate in ([parser] if parser is not None
                          else self.robots_cache.values()):
            if candidate is None:
                continue
            try:
                crawl_delay = candidate.crawl_delay(USER_AGENT)
            except Exception:
                crawl_delay = None
            if crawl_delay:
                base = max(base, float(crawl_delay))
        return base

    # -- fetching ---------------------------------------------------------------

    def fetch_one(self, url):
        host = urllib.parse.urlsplit(url).netloc
        if host in self.force_http_hosts and url.startswith("https://"):
            url = "http://" + url[len("https://"):]
        request = urllib.request.Request(
            safe_request_url(url), headers={
                "User-Agent": USER_AGENT,
                "Accept": "*/*",
                "Accept-Encoding": "identity",
            })
        with urllib.request.urlopen(request, timeout=self.timeout) as resp:
            body = resp.read(self.max_bytes + 1)
            return resp.headers.get("Content-Type", ""), body, resp.geturl()

    def fetch_with_retries(self, url):
        attempt = 0
        while True:
            try:
                ctype, body, final = self.fetch_one(url)
                return "ok", ctype, body, final
            except urllib.error.HTTPError as exc:
                code = exc.code
                if code in (429, 503) and attempt < self.retries:
                    wait = parse_retry_after(
                        exc.headers, min(30 * (attempt + 1), 120))
                    log(f"rate-limited ({code}) {url} -> sleeping {wait}s")
                    time.sleep(wait)
                    attempt += 1
                    continue
                if 500 <= code < 600 and attempt < self.retries:
                    time.sleep(min(10 * (attempt + 1), 60))
                    attempt += 1
                    continue
                return f"http {code}", None, None, url
            except ssl.SSLError as exc:
                if url.startswith("https://") and attempt == 0:
                    host = urllib.parse.urlsplit(url).netloc
                    log(f"SSL failure talking to {host}; "
                        f"falling back to http for this host")
                    self.force_http_hosts.add(host)
                    self.https_hosts.discard(host)
                    attempt += 1
                    continue
                return f"ssl error: {exc}", None, None, url
            except (urllib.error.URLError, http.client.HTTPException,
                    TimeoutError, OSError) as exc:
                if attempt < self.retries:
                    time.sleep(min(15 * (attempt + 1), 90))
                    attempt += 1
                    continue
                detail = getattr(exc, "reason", exc)
                return f"connection error: {detail}", None, None, url

    # -- content processing -------------------------------------------------------

    def _decompress_body(self, body):
        """Gunzip if needed, reading at most max_bytes of output."""
        if not body.startswith(b"\x1f\x8b"):
            return body
        try:
            with gzip.GzipFile(fileobj=io.BytesIO(body)) as gz:
                limited = gz.read(self.max_bytes + 1)
            if len(limited) > self.max_bytes:
                return b""  # decompression bomb; caller will skip
            return limited
        except (OSError, EOFError):
            return body

    def handle_body(self, url, final_url, ctype, body):
        body = self._decompress_body(body)
        rel = url_to_relpath(final_url)
        self.urlmap[url] = rel
        self.urlmap[canonical_url(final_url)] = rel
        ctype_main = (ctype or "").split(";")[0].strip().lower()
        low_final = final_url.lower()
        looks_html = (ctype_main in PAGE_TYPES
                      or low_final.endswith((".html", ".htm", ".xhtml")))
        looks_css = (ctype_main == "text/css" or low_final.endswith(".css"))
        if looks_html:
            self.save_html(url, final_url, rel, ctype, body)
        elif looks_css:
            text, charset = decode_text(body, sniff_charset(ctype, body))
            if text is None:
                write_file(self.out_dir, rel, body)
            else:
                links = []
                new_text, _ = self.map_css(final_url, rel, text, links)
                data = (new_text.encode(charset, "replace")
                        if new_text != text else body)
                write_file(self.out_dir, rel, data)
                for link in links:
                    try:
                        self.enqueue(urllib.parse.urljoin(final_url, link))
                    except ValueError:
                        pass
        else:
            write_file(self.out_dir, rel, body)

    def save_html(self, url, page_url, rel, ctype, body):
        text, charset = decode_text(body, sniff_charset(ctype, body))
        if text is None:
            write_file(self.out_dir, rel, body)
            return
        extractor = LinkExtractor()
        try:
            extractor.feed(text)
            extractor.close()
        except Exception:
            pass
        base = page_url
        if extractor.base_href:
            try:
                base = urllib.parse.urljoin(
                    page_url, extractor.base_href.strip())
            except ValueError:
                base = page_url

        # inline <style> blocks carry CSS urls
        css_links = []

        def style_repl(m):
            new_inner, _ = self.map_css(page_url, rel, m.group(2), css_links)
            return m.group(1) + new_inner + m.group(3)

        text = STYLE_BLOCK_RE.sub(style_repl, text)

        # spans of inline <script> bodies: URLs there must not be rewritten
        script_spans = [(m.start(2), m.end(2))
                        for m in SCRIPT_BLOCK_RE.finditer(text)]

        def in_script(position):
            return any(start <= position < end
                       for start, end in script_spans)

        out, pos = [], 0
        for m in ATTR_VALUE_RE.finditer(text):
            if in_script(m.start("value")):
                continue
            attr = m.group("attr").lower().split("=")[0].strip()
            new_val = self.map_attr_value(attr, m.group("value"), base)
            if new_val is None:
                continue
            out.append(text[pos:m.start("value")])
            out.append(html_mod.escape(new_val, quote=False))
            pos = m.end("value")
        out.append(text[pos:])
        new_text = "".join(out)

        data = (new_text.encode(charset, "replace")
                if new_text != text else body)
        write_file(self.out_dir, rel, data)
        for link in extractor.urls:
            try:
                self.enqueue(urllib.parse.urljoin(base, link.strip()))
            except ValueError:
                pass
        for link in css_links:
            try:
                self.enqueue(urllib.parse.urljoin(page_url, link))
            except ValueError:
                pass

    def map_css(self, css_url, rel, text, links_out):
        def import_repl(m):
            links_out.append(m.group(2))
            mapped = self.map_one_url(m.group(2), css_url)
            if mapped is None:
                return m.group(0)
            return f'@import "{mapped}"'

        def url_repl(m):
            links_out.append(m.group(2))
            mapped = self.map_one_url(m.group(2), css_url)
            if mapped is None:
                return m.group(0)
            return f"url({m.group(1)}{mapped}{m.group(1)})"

        new = CSS_IMPORT_RE.sub(import_repl, text)
        new = CSS_URL_RE.sub(url_repl, new)
        return new, links_out

    def map_attr_value(self, attr, raw_value, base):
        value = html_mod.unescape(raw_value).strip()
        if not value:
            return None
        low = value.lower()
        if low.startswith(("#", "javascript:", "mailto:", "tel:", "data:",
                           "about:")):
            return None
        if attr == "srcset":
            out, changed = [], False
            for candidate in value.split(","):
                candidate = candidate.strip()
                if not candidate:
                    continue
                pieces = candidate.split()
                mapped = self.map_one_url(pieces[0], base)
                if mapped is not None:
                    changed = True
                    pieces[0] = mapped
                out.append(" ".join(pieces))
            return ", ".join(out) if changed else None
        return self.map_one_url(value, base)

    def map_one_url(self, value, base):
        try:
            target = urllib.parse.urljoin(base, value)
        except ValueError:
            return None
        sp = urllib.parse.urlsplit(target)
        if sp.scheme.lower() not in ("http", "https"):
            return None
        canonical = canonical_url(target)
        host = urllib.parse.urlsplit(canonical).netloc
        if host not in self.allowed_hosts:
            return None
        local = self.urlmap.get(canonical) or url_to_relpath(canonical)
        mapped = root_relative_href(local)
        fragment = sp.fragment
        if fragment and not re.search(r"""["'<>]""", fragment):
            mapped += "#" + fragment
        return mapped

    # -- sitemap seeding -----------------------------------------------------------

    def seed_sitemaps(self):
        for netloc, parser in list(self.robots_cache.items()):
            if parser is None:
                continue
            try:
                maps = parser.site_maps() or []
            except Exception:
                maps = []
            for sitemap_url in maps:
                self.fetch_sitemap(sitemap_url, depth=0)

    def fetch_sitemap(self, url, depth):
        if depth > MAX_SITEMAP_DEPTH:
            return
        state, _ctype, body, _final = self.fetch_with_retries(url)
        time.sleep(self.effective_delay())
        if state != "ok" or body is None:
            log(f"sitemap fetch failed: {url} [{state}]")
            return
        if len(body) > MAX_SITEMAP_BYTES:
            log(f"sitemap too large, skipped: {url}")
            return
        text = body.decode("utf-8", "replace")
        # simple extraction instead of a full XML parser
        locs = re.findall(r"<loc>\s*([^<\s]+)\s*</loc>", text,
                          re.IGNORECASE)
        is_index = "<sitemapindex" in text[:512].lower()
        if is_index:
            for loc in locs:
                self.fetch_sitemap(loc, depth + 1)
        else:
            for loc in locs:
                self.enqueue(loc)
            log(f"sitemap {url}: enqueued {len(locs)} URLs")

    # -- main loop --------------------------------------------------------------------

    def crawl(self):
        self.seed()
        if self.host_blocked(urllib.parse.urlsplit(self.start_url).netloc):
            raise SystemExit(
                f"refusing to crawl non-public host: {self.start_url}")
        log(f"crawling {self.start_url} -> {self.out_dir} "
            f"(hosts: {sorted(self.allowed_hosts)})")
        self.robots_for(self.start_url)
        if not self.queue:
            self.seed_sitemaps()
        try:
            self._loop()
        except KeyboardInterrupt:
            log("interrupted; state saved")
        finally:
            self.save_state()
            self.write_failed_report()
        self.report()

    def _loop(self):
        while self.queue:
            if self.max_pages and self.counts["fetched"] >= self.max_pages:
                log(f"stopping: reached --max-pages {self.max_pages}")
                return
            url = self.queue.popleft()
            status = self.seen.get(url)
            if status not in (None, "queued"):
                continue
            parser = self.robots_for(url)
            if parser is not None and not parser.can_fetch(USER_AGENT, url):
                self.seen[url] = "robots-disallowed"
                self.counts["robots"] += 1
                log(f"robots-disallowed: {url}")
                continue
            start = time.monotonic()
            state, ctype, body, final = self.fetch_with_retries(url)
            elapsed = time.monotonic() - start
            if state == "ok":
                final_host = urllib.parse.urlsplit(final).netloc
                if final_host not in self.allowed_hosts:
                    self.seen[url] = "redirected-external"
                    self.counts["failed"] += 1
                    log(f"redirected off-site: {url} -> {final}")
                elif body == b"":
                    self.seen[url] = "empty-body"
                    self.counts["skipped"] += 1
                    log(f"skipped empty or decompression-limited body: {url}")
                elif len(body) > self.max_bytes:
                    self.seen[url] = "too-big"
                    self.counts["skipped"] += 1
                    log(f"skipped (>{self.max_bytes // (1024 * 1024)} MB): "
                        f"{url}")
                else:
                    try:
                        self.handle_body(url, final, ctype, body)
                    except Exception as exc:
                        self.seen[url] = f"processing error: {exc}"
                        self.counts["failed"] += 1
                        log(f"processing failed: {url}: {exc}")
                    else:
                        self.seen[url] = "done"
                        self.counts["written"] += 1
                    self.counts["fetched"] += 1
                    log(f"OK {len(body) // 1024}KB {elapsed:.1f}s "
                        f"q={len(self.queue)} {url}")
            else:
                self.seen[url] = state
                self.counts["failed"] += 1
                log(f"FAILED [{state}] {url}")
            if (self.counts["fetched"]
                    and self.counts["fetched"] % 25 == 0):
                self.save_state()
                log(f"progress: {dict(self.counts)} queue={len(self.queue)}")
            time.sleep(self.effective_delay(parser))
        log("queue drained")

    def report(self):
        files = total = 0
        skip_names = {STATE_NAME, FAILED_NAME, LOG_NAME}
        for p in Path(self.out_dir).rglob("*"):
            if p.is_file() and p.name not in skip_names:
                files += 1
                try:
                    total += p.stat().st_size
                except OSError:
                    pass
        log(f"done: fetched={self.counts['fetched']} "
            f"written={self.counts['written']} "
            f"skipped={self.counts['skipped']} "
            f"failed={self.counts['failed']} "
            f"robots-blocked={self.counts['robots']}")
        log(f"files on disk: {files} ({total / (1024 * 1024):.1f} MB) "
            f"under {self.out_dir}")
        if self.counts["failed"]:
            log(f"failures listed in {FAILED_NAME}")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Slow, polite, resumable mirror of a single website.")
    parser.add_argument("start_url", help="URL to start crawling from")
    parser.add_argument("out_dir", help="directory to save the mirror into")
    parser.add_argument("--delay", type=float, default=2.0,
                        help="seconds between requests (default 2)")
    parser.add_argument("--jitter", type=float, default=1.0,
                        help="extra random delay up to N seconds (default 1)")
    parser.add_argument("--max-pages", type=int, default=50000,
                        help="hard cap on fetched requests (default 50000)")
    parser.add_argument("--max-mb", type=float, default=200.0,
                        help="skip any single file larger than this many MB")
    parser.add_argument("--timeout", type=int, default=60,
                        help="per-request timeout in seconds")
    parser.add_argument("--retries", type=int, default=3,
                        help="retries per request on transient failures")
    parser.add_argument("--extra-host", action="append", default=[],
                        help="also allow crawling this host (repeatable)")
    parser.add_argument("--fresh", action="store_true",
                        help="ignore and delete previous crawl state")
    parser.add_argument("--retry-failed", action="store_true",
                        help="re-fetch URLs that failed in previous runs")
    args = parser.parse_args(argv)

    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    global LOG_FILE
    log_path = contained_path(args.out_dir, LOG_NAME)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    LOG_FILE = log_path.open("a", encoding="utf-8", errors="replace")

    mirror = SiteMirror(
        args.start_url, args.out_dir,
        delay=args.delay, jitter=args.jitter, max_pages=args.max_pages,
        max_bytes=int(args.max_mb * 1024 * 1024), timeout=args.timeout,
        retries=args.retries, fresh=args.fresh,
        retry_failed=args.retry_failed, extra_hosts=args.extra_host)
    mirror.crawl()
    return 0


if __name__ == "__main__":
    sys.exit(main())
