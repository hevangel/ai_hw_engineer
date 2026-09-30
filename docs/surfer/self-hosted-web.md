# Self-hosted Surfer web viewer

The project Docker image can serve Surfer's WebAssembly UI and a local Surver
waveform server. The UI and server run from the image; the waveform file is
mounted read-only. The browser connects to the local server and requests the
waveform data it needs, so the FST is not uploaded to Surfer's hosted app.

The launcher binds the web UI to `127.0.0.1` on the host. The UI proxies
waveform API requests to Surver inside the same container, so the browser uses
one origin and does not block the connection as a cross-origin request. The
proxy preserves Surver's `Server: Surfer` header, which the WASM UI uses to
recognize that the URL is a remote-server connection.

## Build the image

From the repository root in WSL or another shell with Docker access:

```sh
docker build -t ai-hw-engineer:surfer-web .
```

The image builds the browser assets and the `surver` binary from the pinned
Surfer revision. It uses Trunk 0.21.14 and Surfer's upstream WebAssembly build
settings.

## Open a waveform

From the repository root, pass the waveform path to the launcher:

```sh
sh scripts/run_surfer_web.sh design/alu_74181/work/sim/alu_74181.fst
```

The launcher mounts the waveform's containing directory read-only, starts the
web UI and Surver in Docker, and prints a local URL that opens the selected FST
automatically. The default host port is `18080`, leaving the common `8080`
port free. Open the printed URL in a browser. Press `Ctrl+C` in the launcher
terminal to stop the services.

For a waveform outside the repository, pass its absolute WSL path. To change
the default host port, set `SURFER_WEB_PORT` before running the script.

The server streams requested waveform information to the browser through the
local web UI. This avoids uploading the full FST through a browser file picker,
but the browser still receives the values it renders. Keep this setup local;
the connection is not encrypted.
