#!/usr/bin/env python3
"""Build, smoke-test and publish the EDA Docker image to Docker Hub.

The image is tagged `YYYY.MM.DD-<commit>` and `latest`, carries OCI labels for
the source commit, and the Docker Hub overview is regenerated from
docs/dockerhub/overview.md, docs/toolchain-releases.md and the tool versions
reported by the freshly built image. The repository is created public if it
does not exist yet.

Full publishing needs DOCKERHUB_USERNAME and DOCKERHUB_TOKEN (a Docker Hub
personal access token with read, write and delete scope), from the environment
or the Git-ignored .env file in the primary checkout. Environment variables
take precedence over .env.
"""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "docs/dockerhub/overview.md"
MANIFEST = ROOT / "docs/toolchain-releases.md"
SOURCE_URL = "https://github.com/hevangel/ai_hw_engineer"
HUB_API = "https://hub.docker.com"
IMAGE_NAME = "ai-hw-engineer"
PLATFORM = "linux/amd64"
SHORT_DESCRIPTION = ("Pinned open-source EDA toolchain: Verilator, Yosys, SymbiYosys, "
                     "EQY, xezim, Surfer, Verible, UVM")
FULL_DESCRIPTION_LIMIT = 25000
# Tool name and the command whose first output line reports its version.
VERSION_COMMANDS = (
    ("Verilator", "verilator --version"),
    ("Yosys", "yosys --version"),
    ("xezim", "xezim -V"),
    ("Surfer", "surfer --version"),
    ("Verible", "verible-verilog-lint --version"),
    ("Yices", "yices-smt2 --version"),
    ("Z3", "z3 --version"),
    ("Python", "python3 --version"),
    ("Ubuntu", ". /etc/os-release && echo \"$PRETTY_NAME\""),
)


def run(command, **kwargs):
    print("+ " + " ".join(command), flush=True)
    return subprocess.run(command, cwd=ROOT, check=True, **kwargs)


def default_env_file():
    """Use .env in this checkout, or in the primary checkout for a worktree/<task> checkout."""
    candidates = [ROOT / ".env"]
    if ROOT.parent.name == "worktree":
        candidates.append(ROOT.parents[1] / ".env")
    return next((path for path in candidates if path.is_file()), None)


def parse_env(text):
    """Parse KEY=VALUE lines; supports comments, blank lines, `export` and quotes."""
    values = {}
    for number, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.removeprefix("export ").partition("=")
        key, value = key.strip(), value.strip()
        if not separator or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise ValueError(f".env line {number} is not KEY=VALUE")
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        values[key] = value
    return values


def load_env(path):
    """Add .env values to os.environ without overriding variables already set."""
    if path is None:
        return
    for key, value in parse_env(path.read_text(encoding="utf-8-sig")).items():
        os.environ.setdefault(key, value)
    print(f"Loaded settings from {path}")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def version_tag(now, revision):
    return f"{now:%Y.%m.%d}-{revision[:7]}"


def check_source(allow_unmerged):
    """Return the commit to publish after checking that it is clean and reviewed."""
    if git("status", "--porcelain", "--untracked-files=no"):
        raise ValueError("Tracked files have uncommitted changes; publish a committed revision")
    uvm = git("submodule", "status", "libs/uvm")
    if uvm[:1] in {"-", "+", "U"}:
        raise ValueError("libs/uvm is not checked out at its pinned commit; run git submodule update --init libs/uvm")
    revision = git("rev-parse", "HEAD")
    if not allow_unmerged:
        subprocess.run(["git", "fetch", "--quiet", "origin", "main"], cwd=ROOT, check=True)
        merged = subprocess.run(["git", "merge-base", "--is-ancestor", revision, "origin/main"], cwd=ROOT)
        if merged.returncode != 0:
            raise ValueError("HEAD is not on origin/main; publish a reviewed commit or pass --allow-unmerged")
    return revision


def oci_labels(revision, version, created):
    return {
        "org.opencontainers.image.title": IMAGE_NAME,
        "org.opencontainers.image.description": SHORT_DESCRIPTION,
        "org.opencontainers.image.source": SOURCE_URL,
        "org.opencontainers.image.url": SOURCE_URL,
        "org.opencontainers.image.documentation": f"{SOURCE_URL}/blob/{revision}/docs/dockerhub/overview.md",
        "org.opencontainers.image.revision": revision,
        "org.opencontainers.image.version": version,
        "org.opencontainers.image.created": created,
        "org.opencontainers.image.base.name": "docker.io/library/ubuntu:26.04",
    }


def runtime_versions(image):
    """Run the image once and collect the first output line of each version command."""
    script = "".join(f"echo '@@{name}'; ({command}) 2>&1 | head -n 1; "
                     for name, command in VERSION_COMMANDS)
    output = subprocess.check_output(["docker", "run", "--rm", image, "sh", "-c", script],
                                     cwd=ROOT, text=True)
    return parse_versions(output)


def parse_versions(output):
    versions, current = {}, None
    for line in output.splitlines():
        if line.startswith("@@"):
            current = line[2:]
        elif current and current not in versions and line.strip():
            versions[current] = " ".join(line.split())
    missing = [name for name, _ in VERSION_COMMANDS if name not in versions]
    if missing:
        raise ValueError("No version output from: " + ", ".join(missing))
    return versions


def versions_table(versions):
    rows = ["| Tool | Reported version |", "|---|---|"]
    rows += [f"| {name} | `{value.replace('|', '/')}` |" for name, value in versions.items()]
    return "\n".join(rows)


def toolchain_table(manifest):
    """Extract the release-pin table from the manifest."""
    match = re.search(r"^\| Component \|.*?(?=\n\n)", manifest, re.MULTILINE | re.DOTALL)
    if not match:
        raise ValueError("docs/toolchain-releases.md has no '| Component |' table")
    return match.group(0)


def render_overview(template, values):
    text = template
    for key, value in values.items():
        text = text.replace("{{" + key + "}}", value)
    leftover = sorted(set(re.findall(r"\{\{[A-Z_]+\}\}", text)))
    if leftover:
        raise ValueError("Unfilled overview placeholders: " + ", ".join(leftover))
    if len(text) > FULL_DESCRIPTION_LIMIT:
        raise ValueError(f"Overview is {len(text)} characters; Docker Hub allows {FULL_DESCRIPTION_LIMIT}")
    return text


class DockerHub:
    def __init__(self, username, token):
        self.token = self.call("POST", "/v2/auth/token",
                               {"identifier": username, "secret": token})["access_token"]

    def call(self, method, path, body=None):
        headers = {"Content-Type": "application/json", "User-Agent": "ai-hw-engineer-publish"}
        if getattr(self, "token", None):
            headers["Authorization"] = "Bearer " + self.token
        data = None if body is None else json.dumps(body).encode()
        with urlopen(Request(HUB_API + path, data=data, headers=headers, method=method), timeout=60) as response:
            payload = response.read()
        return json.loads(payload) if payload else {}

    def repository(self, namespace, name):
        try:
            return self.call("GET", f"/v2/namespaces/{namespace}/repositories/{name}")
        except HTTPError as error:
            if error.code == 404:
                return None
            raise

    def ensure_public(self, namespace, name, overview):
        repo = self.repository(namespace, name)
        if repo is None:
            print(f"Creating public Docker Hub repository {namespace}/{name}")
            self.call("POST", f"/v2/namespaces/{namespace}/repositories",
                      {"namespace": namespace, "name": name, "is_private": False,
                       "description": SHORT_DESCRIPTION, "full_description": overview})
        elif repo.get("is_private"):
            print(f"Making Docker Hub repository {namespace}/{name} public")
            try:
                self.call("POST", f"/v2/repositories/{namespace}/{name}/privacy/", {"is_private": False})
            except HTTPError as error:
                raise ValueError(f"Could not make {namespace}/{name} public (HTTP {error.code}); "
                                 "set Visibility to Public in the repository settings on hub.docker.com") from error

    def update_overview(self, namespace, name, overview):
        self.call("PATCH", f"/v2/repositories/{namespace}/{name}/",
                  {"description": SHORT_DESCRIPTION, "full_description": overview})


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true",
                      help="check the source and print tags and overview; no build or Docker Hub changes")
    mode.add_argument("--no-push", action="store_true",
                      help="build and smoke-test the image and render the overview; no Docker Hub changes")
    parser.add_argument("--repository",
                        help="Docker Hub repository NAMESPACE/NAME "
                             "(default: $DOCKERHUB_REPOSITORY or $DOCKERHUB_USERNAME/" + IMAGE_NAME + ")")
    parser.add_argument("--env-file", type=Path,
                        help="KEY=VALUE credentials file (default: .env in the primary checkout)")
    parser.add_argument("--no-latest", action="store_true", help="do not move the latest tag")
    parser.add_argument("--allow-unmerged", action="store_true",
                        help="allow publishing a commit that is not on origin/main")
    parser.add_argument("--build-jobs", type=int, help="BUILD_JOBS Docker build argument")
    parser.add_argument("--overview-out", type=Path, help="also write the rendered overview to this file")
    args = parser.parse_args(argv)

    if args.env_file and not args.env_file.is_file():
        parser.error(f"--env-file {args.env_file} does not exist")
    load_env(args.env_file or default_env_file())
    username = os.environ.get("DOCKERHUB_USERNAME", "")
    token = os.environ.get("DOCKERHUB_TOKEN", "")
    repository = (args.repository or os.environ.get("DOCKERHUB_REPOSITORY")
                  or (f"{username}/{IMAGE_NAME}" if username else ""))
    if not re.fullmatch(r"[a-z0-9]+(?:[._-][a-z0-9]+)*/[a-z0-9]+(?:[._-][a-z0-9]+)*", repository):
        parser.error("set --repository NAMESPACE/NAME or DOCKERHUB_USERNAME (lowercase Docker Hub names)")
    namespace, name = repository.split("/")
    publishing = not (args.dry_run or args.no_push)
    if publishing and not (username and token):
        parser.error("set DOCKERHUB_USERNAME and DOCKERHUB_TOKEN to publish")

    revision = check_source(args.allow_unmerged)
    now = datetime.now(timezone.utc)
    version = version_tag(now, revision)
    tags = [f"{repository}:{version}"] + ([] if args.no_latest else [f"{repository}:latest"])
    print(f"Publishing {revision} as: " + ", ".join(tags))

    values = {
        "IMAGE": repository,
        "VERSION": version,
        "REVISION": revision,
        "REVISION_URL": f"{SOURCE_URL}/commit/{revision}",
        "BUILD_DATE": now.date().isoformat(),
        "TOOLCHAIN_TABLE": toolchain_table(MANIFEST.read_text(encoding="utf-8")),
        "RUNTIME_VERSIONS": "_Collected from the built image during publishing._",
    }
    template = TEMPLATE.read_text(encoding="utf-8")
    render_overview(template, values)  # Validate the template before the long build.

    hub = None
    if publishing:
        hub = DockerHub(username, token)  # Fail on bad credentials before building.
        run(["docker", "login", "--username", username, "--password-stdin"], input=token, text=True)

    if not args.dry_run:
        command = ["docker", "build", "--progress=plain", "--platform", PLATFORM]
        for key, value in oci_labels(revision, version, now.isoformat(timespec="seconds")).items():
            command += ["--label", f"{key}={value}"]
        if args.build_jobs:
            command += ["--build-arg", f"BUILD_JOBS={args.build_jobs}"]
        for tag in tags:
            command += ["-t", tag]
        run(command + ["."])
        versions = runtime_versions(tags[0])
        values["RUNTIME_VERSIONS"] = versions_table(versions)
        print(values["RUNTIME_VERSIONS"])

    overview = render_overview(template, values)
    if args.overview_out:
        args.overview_out.write_text(overview, encoding="utf-8", newline="\n")
        print(f"Overview written to {args.overview_out}")
    if args.dry_run:
        print(overview)
        return
    if not publishing:
        print("Image built and smoke-tested; nothing was pushed.")
        return

    hub.ensure_public(namespace, name, overview)
    for tag in tags:
        run(["docker", "push", tag])
    hub.update_overview(namespace, name, overview)
    digest = subprocess.check_output(["docker", "image", "inspect", "--format",
                                      "{{index .RepoDigests 0}}", tags[0]], cwd=ROOT, text=True).strip()
    print(f"Published {digest}")
    print(f"https://hub.docker.com/r/{repository}")


if __name__ == "__main__":
    try:
        main()
    except HTTPError as error:
        detail = error.read().decode(errors="replace")[:500]
        print(f"ERROR: Docker Hub API {error.code} for {error.url}: {detail}", file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError, URLError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
