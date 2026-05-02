# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION} AS downloader

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ARG NODE_VERSION=24.14.1
ARG NODE_LINUX_X64_SHA256=84d38715d449447117d05c3e71acd78daa49d5b1bfa8aacf610303920c3322be
ARG NODE_LINUX_ARM64_SHA256=71e427e28b78846f201d4d5ecc30cb13d1508ca099ef3871889a1256c7d6f67e
ARG APKTOOL_VERSION=3.0.1
ARG APKTOOL_SHA256=b947b945b4bc455609ba768d071b64d9e63834079898dbaae15b67bf03bcd362
ARG JADX_VERSION=1.5.5
ARG JADX_SHA256=38a5766d3c8170c41566b4b13ea0ede2430e3008421af4927235c2880234d51a
ARG DEX2JAR_VERSION=2.4
ARG ANDROID_NDK_VERSION=29.0.14206865
ARG ANDROID_NDK_REVISION=r29
ARG ANDROID_NDK_LINUX_SHA1=87e2bb7e9be5d6a1c6cdf5ec40dd4e0c6d07c30b
ARG ANDROID_NDK_ARM64_URL=https://github.com/lzhiyong/termux-ndk/releases/download/android-ndk/android-ndk-r29-aarch64.7z
ARG ANDROID_NDK_ARM64_SHA256=21ca4237997da6c601eda6de48418609d6d8308b26c631620ae57cf1fa06c4c7

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        p7zip-full \
        unzip \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN case "${TARGETARCH}" in \
        amd64) node_arch='x64'; node_sha="${NODE_LINUX_X64_SHA256}" ;; \
        arm64) node_arch='arm64'; node_sha="${NODE_LINUX_ARM64_SHA256}" ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSLo node.tar.xz \
        "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
    && echo "${node_sha}  node.tar.xz" | sha256sum -c - \
    && mkdir -p /opt/node \
    && tar -xJf node.tar.xz -C /opt/node --strip-components=1

RUN curl -fsSLo apktool.jar \
        "https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VERSION}/apktool_${APKTOOL_VERSION}.jar" \
    && echo "${APKTOOL_SHA256}  apktool.jar" | sha256sum -c -

RUN curl -fsSLo jadx.zip \
        "https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip" \
    && echo "${JADX_SHA256}  jadx.zip" | sha256sum -c - \
    && unzip -q jadx.zip -d /opt/jadx \
    && chmod +x /opt/jadx/bin/*

RUN curl -fsSLo dex2jar.zip \
        "https://github.com/pxb1988/dex2jar/releases/download/v${DEX2JAR_VERSION}/dex-tools-v${DEX2JAR_VERSION}.zip" \
    && unzip -q dex2jar.zip -d /opt \
    && mv /opt/dex-tools-v${DEX2JAR_VERSION} /opt/dex2jar \
    && find /opt/dex2jar -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} +

RUN if [ "${TARGETARCH}" = "amd64" ]; then \
        curl -fsSLo android-ndk-linux.zip \
            "https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_REVISION}-linux.zip" \
        && echo "${ANDROID_NDK_LINUX_SHA1}  android-ndk-linux.zip" | sha1sum -c - \
        && unzip -q android-ndk-linux.zip -d /opt \
        && mv "/opt/android-ndk-${ANDROID_NDK_REVISION}" /opt/android-ndk \
    ; elif [ "${TARGETARCH}" = "arm64" ]; then \
        curl -fsSLo android-ndk-arm64.7z "${ANDROID_NDK_ARM64_URL}" \
        && echo "${ANDROID_NDK_ARM64_SHA256}  android-ndk-arm64.7z" | sha256sum -c - \
        && 7z x -snld -y android-ndk-arm64.7z -o/opt \
        && mv "/opt/android-ndk-${ANDROID_NDK_REVISION}" /opt/android-ndk \
    ; else \
        echo "Unsupported TARGETARCH for NDK install: ${TARGETARCH}" >&2 \
        && exit 1 \
    ; fi

FROM ubuntu:${UBUNTU_VERSION}

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_VERSION=24.14.1
ARG APKTOOL_VERSION=3.0.1
ARG JADX_VERSION=1.5.5
ARG DEX2JAR_VERSION=2.4
ARG ANDROID_NDK_VERSION=29.0.14206865
ARG FRIDA_TOOLS_VERSION=14.8.1
ARG OBJECTION_VERSION=1.12.4
ARG ANDROGUARD_VERSION=4.1.3
ARG MITMPROXY_VERSION=12.2.1
ARG CODEX_VERSION=0.118.0
ARG OPENCODE_VERSION=1.4.1
ARG CLAUDE_CODE_VERSION=2.1.97
ARG DLV_VERSION=1.26.3
ARG GORESYM_VERSION=1.7.1
ARG REDRESS_VERSION=1.2.64

ENV LANG=C.UTF-8 \
    ANDROID_NDK_HOME=/opt/android-ndk \
    ANDROID_NDK_ROOT=/opt/android-ndk \
    LC_ALL=C.UTF-8 \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_PREFIX=/opt/node \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/node/bin:/opt/venv/bin:/opt/jadx/bin:/opt/dex2jar:/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin:/opt/android-tools/bin:${PATH}"

WORKDIR /workspace

COPY --from=downloader /opt/node /opt/node

# Use distro adb/fastboot packages so the runtime image stays native on both
# linux/amd64 and linux/arm64. Ubuntu's Google platform-tools installer is
# amd64-only.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        aapt \
        adb \
        apksigner \
        binutils \
        binwalk \
        bubblewrap \
        checksec \
        curl \
        elfutils \
        fastboot \
        file \
        gdb \
        gdb-multiarch \
        git \
        golang-go \
        jq \
        less \
        lsof \
        ltrace \
        openjdk-17-jre-headless \
        openssh-client \
        patchelf \
        procps \
        psmisc \
        python3 \
        python3-venv \
        radare2 \
        sqlite3 \
        strace \
        tcpdump \
        tmux \
        unzip \
        usbutils \
        vim \
        zipalign \
    && python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel \
    && /opt/venv/bin/pip install --no-cache-dir \
        "androguard==${ANDROGUARD_VERSION}" \
        "frida-tools==${FRIDA_TOOLS_VERSION}" \
        "mitmproxy==${MITMPROXY_VERSION}" \
        "objection==${OBJECTION_VERSION}" \
    && npm install --global \
        "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
        "@openai/codex@${CODEX_VERSION}" \
        "opencode-ai@${OPENCODE_VERSION}" \
    && mkdir -p /opt/android-tools/bin \
    && GOBIN=/opt/android-tools/bin go install "github.com/go-delve/delve/cmd/dlv@v${DLV_VERSION}" \
    && GOBIN=/opt/android-tools/bin go install "github.com/mandiant/GoReSym@v${GORESYM_VERSION}" \
    && GOBIN=/opt/android-tools/bin go install "github.com/goretk/redress@v${REDRESS_VERSION}" \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

COPY --from=downloader /tmp/apktool.jar /opt/apktool/apktool.jar
COPY --from=downloader /opt/jadx /opt/jadx
COPY --from=downloader /opt/dex2jar /opt/dex2jar
COPY --from=downloader /opt/android-ndk /opt/android-ndk

RUN mkdir -p /opt/android-tools/bin \
    && cat > /opt/android-tools/bin/apktool <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec java -jar /opt/apktool/apktool.jar "$@"
EOF

RUN chmod +x /opt/android-tools/bin/apktool \
    && for script in /opt/dex2jar/*.sh; do \
        ln -sf "$(basename "$script")" "/opt/dex2jar/$(basename "${script%.sh}")"; \
    done

RUN cat > /opt/android-tools/bin/tool-versions <<EOF
#!/usr/bin/env bash
set -euo pipefail

printf 'nodejs=%s\n' '${NODE_VERSION}'
printf 'npm=%s\n' "\$(npm --version)"
printf 'codex=%s\n' "\$(node -p "require('/opt/node/lib/node_modules/@openai/codex/package.json').version")"
printf 'opencode=%s\n' "\$(node -p "require('/opt/node/lib/node_modules/opencode-ai/package.json').version")"
printf 'claude-code=%s\n' "\$(node -p "require('/opt/node/lib/node_modules/@anthropic-ai/claude-code/package.json').version")"
printf 'apktool=%s\n' '${APKTOOL_VERSION}'
printf 'jadx=%s\n' '${JADX_VERSION}'
printf 'dex2jar=%s\n' '${DEX2JAR_VERSION}'
printf 'frida-tools=%s\n' '${FRIDA_TOOLS_VERSION}'
printf 'objection=%s\n' '${OBJECTION_VERSION}'
printf 'androguard=%s\n' '${ANDROGUARD_VERSION}'
printf 'mitmproxy=%s\n' "\$(mitmproxy --version | sed -n '1s/^[^:]*: //p')"
printf 'go=%s\n' "\$(go version | awk '{print \$3}')"
printf 'dlv=%s\n' "\$(dlv version | sed -n 's/^Version: //p' | head -n 1)"
printf 'goresym=%s\n' "\$(go version -m "\$(command -v GoReSym)" | awk '\$1~/^mod$/{print \$3; exit}')"
printf 'redress=%s\n' "\$(go version -m "\$(command -v redress)" | awk '\$1~/^mod$/{print \$3; exit}')"
printf 'ssh=%s\n' "\$(ssh -V 2>&1 | sed -n '1s/^OpenSSH_\\([^,]*\\).*/\\1/p')"
printf 'android-ndk=%s\n' "\$(if [ -f /opt/android-ndk/source.properties ]; then sed -n 's/^Pkg.Revision = //p' /opt/android-ndk/source.properties | head -n 1; else printf 'unavailable-linux-%s' \"\$(dpkg --print-architecture)\"; fi)"
printf 'adb=%s\n' "\$(adb version | sed -n '1s/.*version //p')"
printf 'fastboot=%s\n' "\$(fastboot --version | sed -n '1s/fastboot version //p')"
printf 'binutils=%s\n' "\$(dpkg-query -W -f='\${Version}' binutils)"
printf 'bubblewrap=%s\n' "\$(dpkg-query -W -f='\${Version}' bubblewrap)"
printf 'gdb=%s\n' "\$(dpkg-query -W -f='\${Version}' gdb)"
printf 'gdb-multiarch=%s\n' "\$(dpkg-query -W -f='\${Version}' gdb-multiarch)"
printf 'radare2=%s\n' "\$(dpkg-query -W -f='\${Version}' radare2)"
printf 'binwalk=%s\n' "\$(dpkg-query -W -f='\${Version}' binwalk)"
printf 'checksec=%s\n' "\$(dpkg-query -W -f='\${Version}' checksec)"
printf 'ltrace=%s\n' "\$(dpkg-query -W -f='\${Version}' ltrace)"
printf 'lsof=%s\n' "\$(dpkg-query -W -f='\${Version}' lsof)"
printf 'patchelf=%s\n' "\$(dpkg-query -W -f='\${Version}' patchelf)"
printf 'tmux=%s\n' "\$(dpkg-query -W -f='\${Version}' tmux)"
printf 'vim=%s\n' "\$(dpkg-query -W -f='\${Version}' vim)"
EOF

RUN chmod +x /opt/android-tools/bin/tool-versions

EXPOSE 8080 8081

CMD ["bash"]
