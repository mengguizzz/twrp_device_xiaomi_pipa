#!/bin/bash
set -euo pipefail

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    aria2 \
    bc \
    bison \
    build-essential \
    ca-certificates \
    ccache \
    cpio \
    curl \
    file \
    flex \
    fontconfig \
    fonts-dejavu-core \
    g++-multilib \
    gcc-multilib \
    git \
    gnupg \
    gperf \
    imagemagick \
    jq \
    lib32ncurses-dev \
    lib32readline-dev \
    lib32z1-dev \
    libc6-dev-i386 \
    libelf-dev \
    libgl1-mesa-dev \
    liblz4-tool \
    libncurses-dev \
    libssl-dev \
    libtinfo6 \
    libx11-dev \
    libxml2 \
    libxml2-utils \
    lz4 \
    lzop \
    openjdk-17-jdk-headless \
    pngcrush \
    protobuf-compiler \
    python-is-python3 \
    python3 \
    rsync \
    schedtool \
    squashfs-tools \
    unzip \
    xmlstarlet \
    xsltproc \
    xz-utils \
    zip \
    zlib1g-dev \
    zram-tools

mkdir -p "$HOME/.local/bin"
curl --fail --location --retry 5 --retry-delay 3 \
    https://storage.googleapis.com/git-repo-downloads/repo \
    -o "$HOME/.local/bin/repo"
chmod +x "$HOME/.local/bin/repo"
"$HOME/.local/bin/repo" --version
