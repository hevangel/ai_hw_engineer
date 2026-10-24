#!/usr/bin/env python3
"""Refresh the Docker toolchain from official stable releases (Python 3.11+)."""

import argparse
from datetime import datetime, timezone
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tomllib
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlparse
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent.parent
GITHUB = "https://api.github.com/repos/"
SOURCES = {
    "Verilator": ("VERILATOR_REV", "verilator/verilator"),
    "Yosys": ("YOSYS_REV", "YosysHQ/yosys"),
    "SBY": ("SBY_REV", "YosysHQ/sby"),
    "EQY": ("EQY_REV", "YosysHQ/eqy"),
    "Yices": ("YICES_REV", "SRI-CSL/yices2"),
    "xezim": ("XEZIM_REV", "aionhw/xezim"),
}


def request(url):
    headers = {"User-Agent": "ai-hw-engineer-toolchain-updater"}
    # Never send a GitHub credential to archive hosts or other services.
    if urlparse(url).hostname == "api.github.com" and os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GITHUB_TOKEN"]
    return urlopen(Request(url, headers=headers), timeout=60)


def get_json(url):
    with request(url) as response:
        return json.load(response)


def get_text(url):
    with request(url) as response:
        return response.read().decode("utf-8")


def archive_digest(url, expected=None):
    digest = hashlib.sha256()
    with request(url) as response:
        for chunk in iter(lambda: response.read(1024 * 1024), b""):
            digest.update(chunk)
    actual = digest.hexdigest()
    if expected and expected != "sha256:" + actual:
        raise ValueError(f"Published SHA-256 mismatch for {url}")
    return actual


def latest(repo, optional=False):
    try:
        release = get_json(GITHUB + repo + "/releases/latest")
    except HTTPError as error:
        if error.code == 404 and repo == "verilator/verilator":
            # Verilator publishes tags, not GitHub Releases. Its documented
            # stable branch contains released versions. Require a version tag
            # reachable from that branch, since stable may include a merge commit.
            candidates = []
            for page in range(1, 101):
                tags = get_json(GITHUB + repo + f"/tags?per_page=100&page={page}")
                for tag in tags:
                    if re.fullmatch(r"v\d+\.\d+", tag["name"]):
                        candidates.append(tag["name"])
                if not tags:
                    break
            for tag in sorted(candidates, key=lambda t: tuple(map(int, t[1:].split("."))), reverse=True):
                comparison = get_json(GITHUB + repo + "/compare/" + tag + "...stable")
                if comparison["status"] in {"ahead", "identical"}:
                    return {"tag_name": tag, "html_url":
                            "https://github.com/" + repo + "/tree/" + tag}
            raise ValueError("Verilator stable branch has no matching release tag") from error
        if optional and error.code == 404:
            return None
        raise
    if release.get("draft") or release.get("prerelease"):
        raise ValueError(f"Expected a stable published release for {repo}")
    # Only allow tag characters that are safe in Docker ARGs and URLs.
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", release["tag_name"]):
        raise ValueError(f"Unsupported release tag for {repo}")
    return release


def commit_for_tag(repo, tag):
    obj = get_json(GITHUB + repo + "/git/ref/tags/" + quote(tag, safe=""))["object"]
    # Peel annotated tags instead of mistaking the tag object for a commit.
    for _ in range(10):
        if obj["type"] == "commit":
            if not re.fullmatch(r"[0-9a-f]{40}", obj["sha"]):
                raise ValueError(f"Invalid commit for {repo}")
            return obj["sha"]
        if obj["type"] != "tag":
            break
        obj = get_json(GITHUB + repo + "/git/tags/" + obj["sha"])["object"]
    raise ValueError(f"Could not resolve release tag to commit for {repo}")


def asset(release, name):
    matches = [item for item in release["assets"] if item["name"] == name]
    if len(matches) != 1:
        raise ValueError(f"Expected one release asset named {name}; build recipe needs review")
    item = matches[0]
    return archive_digest(item["browser_download_url"], item.get("digest"))


def replace_one(text, pattern, replacement):
    result, count = re.subn(pattern, lambda match: replacement, text, flags=re.MULTILINE)
    if count != 1:
        raise ValueError(f"Expected exactly one match for {pattern!r}, found {count}")
    return result


def arguments(dockerfile):
    return dict(re.findall(r"^ARG ([A-Z0-9_]+)=([^\s]+)", dockerfile, re.MULTILINE))


def discover(current):
    pins = {}
    rows = {}

    def record(name, description, url):
        rows[name] = (description, url)
        print(f"{name}: {description}", file=sys.stderr)

    for name, (arg, repo) in SOURCES.items():
        release = latest(repo, optional=name in {"SBY", "EQY"})
        if release is None:
            record(name, f"snapshot `{current[arg]}` (retained; no standalone release)",
                   "https://github.com/" + repo)
            continue
        tag = release["tag_name"]
        pins[arg] = commit_for_tag(repo, tag)
        record(name, f"{tag}, `{pins[arg]}`", release["html_url"])

    project = "https://gitlab.com/api/v4/projects/surfer-project%2Fsurfer"
    # GitLab orders releases by released_at; skip future releases and prerelease tags.
    surfer = None
    for page in range(1, 101):
        releases = get_json(f"{project}/releases?per_page=100&page={page}")
        for item in releases:
            if (not item.get("upcoming_release")
                    and re.fullmatch(r"v?\d+\.\d+\.\d+", item["tag_name"])
                    and datetime.fromisoformat(item["released_at"].replace("Z", "+00:00"))
                    <= datetime.now(timezone.utc)):
                surfer = item
                break
        if surfer or not releases:
            break
    if not surfer:
        raise ValueError("No stable Surfer release found")
    pins["SURFER_REV"] = surfer["commit"]["id"]
    if not re.fullmatch(r"[0-9a-f]{40}", pins["SURFER_REV"]):
        raise ValueError("Invalid Surfer commit")
    record("Surfer", f"{surfer['tag_name']}, `{pins['SURFER_REV']}`",
           "https://gitlab.com/surfer-project/surfer/-/releases/" + surfer["tag_name"])

    for name, repo, arg, prefix in (
        ("Trunk", "trunk-rs/trunk", "TRUNK_VERSION", "v"),
        ("Verible", "chipsalliance/verible", "VERIBLE_VERSION", ""),
        ("Z3", "Z3Prover/z3", "Z3_VERSION", "z3-"),
    ):
        release = latest(repo)
        tag = release["tag_name"]
        version = tag.removeprefix(prefix)
        if name != "Verible" and not re.fullmatch(r"\d+\.\d+\.\d+", version):
            raise ValueError(f"Unexpected {name} version: {tag}")
        pins[arg] = version
        if name == "Verible":
            pins["VERIBLE_SHA256"] = asset(release, f"verible-{tag}-linux-static-x86_64.tar.gz")
        elif name == "Z3":
            pins["Z3_SHA256"] = asset(release, f"z3-{version}-x64-glibc-2.39.zip")
        elif name == "Trunk":
            # Fail before editing if the binary expected by the build has disappeared.
            if not any(a["name"] == "trunk-x86_64-unknown-linux-gnu.tar.gz" for a in release["assets"]):
                raise ValueError("Trunk release is missing the required Linux archive")
        record(name, version, release["html_url"])

    rust = tomllib.loads(get_text("https://static.rust-lang.org/dist/channel-rust-stable.toml"))
    pins["RUST_VERSION"] = rust["pkg"]["rust"]["version"].split()[0]
    if not re.fullmatch(r"\d+\.\d+\.\d+", pins["RUST_VERSION"]):
        raise ValueError("Invalid stable Rust version")
    record("Rust", pins["RUST_VERSION"], "https://static.rust-lang.org/dist/channel-rust-stable.toml")
    rustup_manifest = "https://static.rust-lang.org/rustup/release-stable.toml"
    pins["RUSTUP_VERSION"] = tomllib.loads(get_text(rustup_manifest))["version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", pins["RUSTUP_VERSION"]):
        raise ValueError("Invalid stable rustup version")
    record("rustup", pins["RUSTUP_VERSION"], rustup_manifest)
    rustup = ("https://static.rust-lang.org/rustup/archive/" + pins["RUSTUP_VERSION"]
              + "/" + current["RUSTUP_TARGET"] + "/rustup-init")
    expected = get_text(rustup + ".sha256").split()[0]
    pins["RUSTUP_INIT_SHA256"] = archive_digest(rustup, "sha256:" + expected)
    cmake = get_json("https://pypi.org/pypi/cmake/json")
    pins["CMAKE_PIP_VERSION"] = cmake["info"]["version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:\.\d+)?", pins["CMAKE_PIP_VERSION"]):
        raise ValueError("Expected a stable CMake package version")
    if not any(not item.get("yanked") for item in cmake["urls"]):
        raise ValueError("CMake release has no non-yanked distributions")
    record("CMake", pins["CMAKE_PIP_VERSION"],
           "https://pypi.org/project/cmake/" + pins["CMAKE_PIP_VERSION"] + "/")
    return pins, rows


def render(dockerfile, readme, manifest, pins, rows):
    for name, value in pins.items():
        dockerfile = replace_one(dockerfile, rf"^ARG {name}=.*$", f"ARG {name}={value}")
    # Keep recipe comments accurate after upgrading without rewriting build steps.
    dockerfile = re.sub(r"# Yosys [\d.]+ uses CMake", "# Yosys uses CMake", dockerfile)
    bullets = "\n".join(f"- **{name} {description.split(', `')[0]}** — [official source]({url})."
                        for name, (description, url) in rows.items())
    bullets += "\n- **UVM** — the repository's pinned submodule copied to `/opt/uvm`."
    readme = replace_one(readme,
                         r"(?s)(?<=The Dockerfile builds a multi-stage image containing:\n\n).*?(?=\n\nThe \[release manifest\])",
                         bullets)
    for name, (description, url) in rows.items():
        manifest = replace_one(manifest, rf"^\| {re.escape(name)} \|.*$",
                               f"| {name} | {description} | [official source]({url}) |")
    date = datetime.now(timezone.utc).date().isoformat()
    manifest = replace_one(manifest, r"(?<=Release discovery date: )\d{4}-\d{2}-\d{2}", date)
    return {"Dockerfile": dockerfile, "README.md": readme, "docs/toolchain-releases.md": manifest}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="show diff without writing or building")
    mode.add_argument("--no-build", action="store_true", help="update pins and docs without building")
    parser.add_argument("--image", default="ai-hw-engineer:latest", help="local image tag")
    args = parser.parse_args(argv)
    if not args.image or args.image.startswith("-"):
        parser.error("--image must be a Docker image tag")
    branch = subprocess.check_output(["git", "branch", "--show-current"], cwd=ROOT, text=True).strip()
    if not args.dry_run and branch in {"", "main", "master"}:
        raise ValueError("Switch to a feature branch before updating toolchain pins")
    paths = ("Dockerfile", "README.md", "docs/toolchain-releases.md")
    original = {path: (ROOT / path).read_text(encoding="utf-8") for path in paths}
    pins, rows = discover(arguments(original["Dockerfile"]))
    updated = render(*(original[path] for path in paths), pins, rows)
    # Validate all replacements before writing any files.
    for path in paths:
        sys.stdout.writelines(difflib.unified_diff(original[path].splitlines(True),
                                                 updated[path].splitlines(True),
                                                 fromfile="a/" + path, tofile="b/" + path))
    if args.dry_run:
        return
    for path in paths:
        if (ROOT / path).read_text(encoding="utf-8") != original[path]:
            raise ValueError(f"{path} changed during discovery; retry without concurrent edits")
    for path in paths:
        if original[path] != updated[path]:
            (ROOT / path).write_text(updated[path], encoding="utf-8", newline="\n")
    print("Pins and documentation updated; review release notes and build compatibility.")
    if not args.no_build:
        subprocess.run(["docker", "build", "--progress=plain", "-t", args.image, "."], cwd=ROOT, check=True)
        print("Docker image built; Dockerfile executable smoke checks passed.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError, URLError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
