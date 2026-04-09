# android-tools

Headless Android debugging, traffic interception, and reverse-engineering toolbox packaged as a multi-platform container image.

## Included tools

The image is intentionally biased toward tools that work well in a CLI-first container:

- Device access: `adb`, `fastboot`
- JavaScript runtime and package manager: `node`, `npm`
- Agent CLIs: `codex`, `opencode`, `claude`
- APK inspection and rebuilds: `apktool`, `aapt`, `apksigner`, `zipalign`
- DEX and Java decompilation: `jadx`, `dex2jar`
- Dynamic instrumentation: `frida-tools`, `objection`
- Traffic interception: `mitmproxy`, `mitmdump`, `mitmweb`
- Static analysis and triage: `androguard`, `file`, `sqlite3`
- Native debugging helpers: `gdb-multiarch`, `strace`, `tcpdump`

Pinned upstream versions in the current Dockerfile:

- `nodejs` `24.14.1`
- `codex` `0.118.0`
- `opencode` `1.4.1`
- `claude-code` `2.1.97`
- `apktool` `3.0.1`
- `jadx` `1.5.5`
- `dex2jar` `2.4`
- `frida-tools` `14.8.1`
- `mitmproxy` `12.2.1`
- `objection` `1.12.4`
- `androguard` `4.1.3`

Run `tool-versions` inside the container to confirm the installed toolchain.

## Research notes

- Google currently documents Platform-Tools revision `36.0.0`, but the Ubuntu `google-android-platform-tools-installer` package is `amd64`-only. This image therefore uses Ubuntu's native `adb` and `fastboot` packages so both `linux/amd64` and `linux/arm64` variants remain usable.
- Ubuntu 24.04 ships Node `18.19.1`, which is older than I want for the current npm-based agent CLIs. The image therefore installs official Node.js LTS `24.14.1` from `nodejs.org`.
- `@openai/codex`, `opencode-ai`, and `@anthropic-ai/claude-code` all publish platform-aware npm packages, so they fit the same multi-arch container model as the rest of this image.
- `apktool`, `jadx`, `dex2jar`, `frida-tools`, `mitmproxy`, `objection`, and `androguard` are current enough to make sense as the default core set for Android app triage, interception, repackaging, and instrumentation.
- `radare2` `6.1.2` and `binwalk` `3.1.0` are relevant for lower-level native or firmware work, but I left them out of the base image because they materially increase build size and Ubuntu's packaged versions lag upstream. If you want them, add them in a derivative image.
- GUI-heavy tools such as Ghidra, Cutter, Android Studio, and full JADX desktop use are better left on the host. The container stays focused on headless workflows.
- `frida-server` is intentionally not bundled because it must match the target Android device architecture and Frida release you are using.
- These agent CLIs do not come pre-authenticated. You still need to pass the relevant credentials or run their normal login flow at container runtime.

## Windows support

Windows support here means Windows hosts running the published Linux image through Docker Desktop:

- `windows/amd64` hosts are supported through Docker Desktop with Linux containers.
- `windows/arm64` hosts are supported through Docker Desktop on Windows Arm using the `linux/arm64` image variant.
- Native `windows/amd64` and `windows/arm64` container images are not published from this repo.

That distinction is deliberate. This toolchain is built on Ubuntu, and the practical cross-host path is to publish `linux/amd64` and `linux/arm64` images and let Docker Desktop handle the host integration on Windows.

## Local usage

Build the image locally:

```bash
docker build -t android-tools:dev .
```

Show the installed tool versions:

```bash
docker run --rm android-tools:dev tool-versions
```

Run the bundled coding agents:

```bash
docker run --rm -it \
  -v "$PWD:/workspace" \
  -e OPENAI_API_KEY \
  android-tools:dev \
  codex --help
```

```bash
docker run --rm -it \
  -v "$PWD:/workspace" \
  -e ANTHROPIC_API_KEY \
  android-tools:dev \
  claude --help
```

```bash
docker run --rm -it \
  -v "$PWD:/workspace" \
  android-tools:dev \
  opencode --help
```

Run `mitmweb` for Android traffic interception:

```bash
docker run --rm -it \
  -p 8080:8080 \
  -p 8081:8081 \
  -v "$PWD/.mitmproxy:/root/.mitmproxy" \
  android-tools:dev \
  mitmweb --listen-host 0.0.0.0 --web-host 0.0.0.0
```

Then browse to `http://localhost:8081` for the web UI and `http://mitm.it` from the device configured to use the proxy on port `8080`.

Decode an APK with `apktool`:

```bash
docker run --rm -it \
  -v "$PWD:/workspace" \
  android-tools:dev \
  apktool d /workspace/app.apk -o /workspace/app-src
```

Decompile an APK with `jadx`:

```bash
docker run --rm -it \
  -v "$PWD:/workspace" \
  android-tools:dev \
  jadx -d /workspace/jadx-out /workspace/app.apk
```

Use `adb` against a USB-connected device:

```bash
docker run --rm -it \
  --privileged \
  -v /dev/bus/usb:/dev/bus/usb \
  android-tools:dev \
  adb devices
```

`adb connect <host>:5555` often works better than raw USB passthrough when you are already using Docker.

On Windows, `adb connect <device-ip>:5555` is usually the more reliable path because USB passthrough into Linux containers depends on Docker Desktop and your local host setup.

## Publishing workflow

The GitHub Actions workflow in `.github/workflows/publish.yml`:

- Builds with Docker Buildx
- Publishes to `ghcr.io/<owner>/<repo>`
- Emits a multi-platform manifest for `linux/amd64` and `linux/arm64`
- Tags the default branch as `latest`
- Tags branch builds with the branch name
- Tags release pushes like `v1.2.3` as `1.2.3` and `1.2`
- Publishes provenance and SBOM attestations

Those Linux variants are the supported path for Linux, macOS, and Windows hosts, including Windows `amd64` and Windows `arm64` through Docker Desktop.

With the current remote, the published image path will be:

```text
ghcr.io/sagerenn/android-tools
```

## Sources

- Google Platform-Tools release notes: <https://developer.android.com/studio/releases/platform-tools>
- Docker Desktop on Windows install docs: <https://docs.docker.com/desktop/setup/install/windows-install/>
- Node.js releases: <https://nodejs.org/dist/index.json>
- Codex on npm: <https://www.npmjs.com/package/@openai/codex>
- Claude Code on npm: <https://www.npmjs.com/package/@anthropic-ai/claude-code>
- OpenCode install script: <https://opencode.ai/install>
- OpenCode on npm: <https://www.npmjs.com/package/opencode-ai>
- Apktool releases: <https://github.com/iBotPeaches/Apktool/releases>
- JADX releases: <https://github.com/skylot/jadx/releases>
- dex2jar releases: <https://github.com/pxb1988/dex2jar/releases>
- Frida tools on PyPI: <https://pypi.org/project/frida-tools/>
- mitmproxy docs: <https://docs.mitmproxy.org/stable/overview/installation/>
- mitmproxy on PyPI: <https://pypi.org/project/mitmproxy/>
- Objection on PyPI: <https://pypi.org/project/objection/>
- Androguard on PyPI: <https://pypi.org/project/androguard/>
- radare2 releases: <https://github.com/radareorg/radare2/releases>
- Binwalk releases: <https://github.com/ReFirmLabs/binwalk/releases>
