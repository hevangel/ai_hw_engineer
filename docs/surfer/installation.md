# Surfer Installation

Source: [surfer-project.org](https://surfer-project.org/)

## Build from Source (Recommended)

### Prerequisites

- Rust toolchain: https://www.rust-lang.org/tools/install
- Platform-specific GUI dependencies (see below)

### Linux Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install libxcb-render0-dev libxcb-shape0-dev \
  libxcb-xfixes0-dev libspeechd-dev libxkbcommon-dev libssl-dev

# Fedora
sudo dnf install libxcb-devel speechd-devel libxkbcommon-devel openssl-devel
```

### Build and Install

```bash
git clone https://gitlab.com/surfer-project/surfer.git
cd surfer
cargo build --release
# Binary at target/release/surfer
```

Or install directly:
```bash
cargo install --git https://gitlab.com/surfer-project/surfer.git
```

## Pre-built Binaries

Download from the Surfer releases page for Linux and Windows:
- https://gitlab.com/surfer-project/surfer/-/releases

## Web Version

No installation needed — use directly in browser:
- https://app.surfer-project.org

Note: Performance is somewhat reduced compared to native, and some features may be missing.

## VS Code Extension

Search for "Surfer" in the VS Code extension marketplace.

## Docker (Headless/CLI)

In the project Docker image, Surfer is available at `/opt/surfer/bin/surfer`.

```bash
# Inside Docker container
surfer dump.vcd  # Opens waveform viewer
```

Note: For GUI display in Docker, you'll need X11 forwarding:
```bash
docker run -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix ...
```

## Verification

```bash
surfer --version
```
