# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION} AS downloader

ARG DEBIAN_FRONTEND=noninteractive
ARG APKTOOL_VERSION=3.0.1
ARG APKTOOL_SHA256=b947b945b4bc455609ba768d071b64d9e63834079898dbaae15b67bf03bcd362
ARG JADX_VERSION=1.5.5
ARG JADX_SHA256=38a5766d3c8170c41566b4b13ea0ede2430e3008421af4927235c2880234d51a
ARG DEX2JAR_VERSION=2.4

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

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

FROM ubuntu:${UBUNTU_VERSION}

ARG DEBIAN_FRONTEND=noninteractive
ARG APKTOOL_VERSION=3.0.1
ARG JADX_VERSION=1.5.5
ARG DEX2JAR_VERSION=2.4
ARG FRIDA_TOOLS_VERSION=14.8.1
ARG OBJECTION_VERSION=1.12.4
ARG ANDROGUARD_VERSION=4.1.3
ARG MITMPROXY_VERSION=12.2.1

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:/opt/jadx/bin:/opt/dex2jar:/opt/android-tools/bin:${PATH}"

WORKDIR /workspace

# Use distro adb/fastboot packages so the runtime image stays native on both
# linux/amd64 and linux/arm64. Ubuntu's Google platform-tools installer is
# amd64-only.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        aapt \
        adb \
        apksigner \
        curl \
        fastboot \
        file \
        gdb-multiarch \
        git \
        jq \
        less \
        openjdk-17-jre-headless \
        python3 \
        python3-venv \
        sqlite3 \
        strace \
        tcpdump \
        unzip \
        usbutils \
        zipalign \
    && python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel \
    && /opt/venv/bin/pip install --no-cache-dir \
        "androguard==${ANDROGUARD_VERSION}" \
        "frida-tools==${FRIDA_TOOLS_VERSION}" \
        "mitmproxy==${MITMPROXY_VERSION}" \
        "objection==${OBJECTION_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

COPY --from=downloader /tmp/apktool.jar /opt/apktool/apktool.jar
COPY --from=downloader /opt/jadx /opt/jadx
COPY --from=downloader /opt/dex2jar /opt/dex2jar

RUN mkdir -p /opt/android-tools/bin \
    && printf '%s\n' \
        '#!/usr/bin/env bash' \
        'set -euo pipefail' \
        'exec java -jar /opt/apktool/apktool.jar "$@"' \
        > /opt/android-tools/bin/apktool \
    && chmod +x /opt/android-tools/bin/apktool \
    && for script in /opt/dex2jar/*.sh; do \
        ln -sf "$(basename "$script")" "/opt/dex2jar/$(basename "${script%.sh}")"; \
    done \
    && printf '%s\n' \
        '#!/usr/bin/env bash' \
        'set -euo pipefail' \
        "printf 'apktool=%s\n' '${APKTOOL_VERSION}'" \
        "printf 'jadx=%s\n' '${JADX_VERSION}'" \
        "printf 'dex2jar=%s\n' '${DEX2JAR_VERSION}'" \
        "printf 'frida-tools=%s\n' '${FRIDA_TOOLS_VERSION}'" \
        "printf 'objection=%s\n' '${OBJECTION_VERSION}'" \
        "printf 'androguard=%s\n' '${ANDROGUARD_VERSION}'" \
        "printf 'mitmproxy=%s\n' \"\$(mitmproxy --version | sed -n '1s/^[^:]*: //p')\"" \
        "printf 'adb=%s\n' \"\$(adb version | sed -n '1s/.*version //p')\"" \
        "printf 'fastboot=%s\n' \"\$(fastboot --version | sed -n '1s/fastboot version //p')\"" \
        > /opt/android-tools/bin/tool-versions \
    && chmod +x /opt/android-tools/bin/tool-versions

EXPOSE 8080 8081

CMD ["bash"]
