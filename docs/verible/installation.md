# Verible Installation

## In Our Docker Image

Verible is installed from pre-built statically-linked Linux x86_64 binaries distributed via GitHub Releases. This avoids the Bazel build dependency.

The Dockerfile stage pins both the release and archive digest:

```dockerfile
FROM base AS verible-download

ARG VERIBLE_VERSION=v0.0-4148-g1ea007ec
ARG VERIBLE_SHA256=5198d7980e5c8e039ad371fd963dfec375aacac1ea80cfa530804b945132ab10

RUN mkdir -p /opt/verible && \
    curl -fsSL "https://github.com/chipsalliance/verible/releases/download/${VERIBLE_VERSION}/verible-${VERIBLE_VERSION}-linux-static-x86_64.tar.gz" \
        -o /tmp/verible.tar.gz && \
    echo "${VERIBLE_SHA256}  /tmp/verible.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/verible.tar.gz --strip-components=1 -C /opt/verible && \
    rm /tmp/verible.tar.gz
```

The binaries are placed in `/opt/verible/bin/` and added to `PATH`.

## Updating the Version

To update Verible to a newer release:

1. Check the [official releases](https://github.com/chipsalliance/verible/releases).
2. Download the Linux static x86_64 archive and calculate its SHA-256 digest with `sha256sum`.
3. Update both `VERIBLE_VERSION` and `VERIBLE_SHA256` in the Dockerfile.
4. Rebuild the image: `docker build -t ai-hw-engineer .`
5. Verify: `docker run --rm ai-hw-engineer verible-verilog-lint --version`

Both values must also be supplied when overriding the pin at build time:

```bash
docker build \
  --build-arg VERIBLE_VERSION=v0.0-XXXX-gYYYYYYYY \
  --build-arg VERIBLE_SHA256=<archive-sha256> \
  -t ai-hw-engineer .
```

## Local Installation (Outside Docker)

### Linux (pre-built binary)

```bash
VERSION=v0.0-4148-g1ea007ec
SHA256=5198d7980e5c8e039ad371fd963dfec375aacac1ea80cfa530804b945132ab10
ARCHIVE="verible-${VERSION}-linux-static-x86_64.tar.gz"
curl -fL "https://github.com/chipsalliance/verible/releases/download/${VERSION}/${ARCHIVE}" \
  -o "${ARCHIVE}"
echo "${SHA256}  ${ARCHIVE}" | sha256sum -c -
tar -xzf "${ARCHIVE}"
sudo cp "verible-${VERSION}"/bin/* /usr/local/bin/
```

### macOS (Homebrew)

```bash
brew tap chipsalliance/verible
brew install verible
```

### Nix

```bash
nix-env -iA nixpkgs.verible
```

### From Source (requires Bazel 7+)

```bash
git clone https://github.com/chipsalliance/verible.git
cd verible
bazel build -c opt //...
```
