# Base dev container image: Debian + Bash tooling.
# PowerShell and Docker-in-Docker are layered on via devcontainer "features"
# (see devcontainer.json), so this Dockerfile only needs to add ShellCheck
# and general CLI utilities.
FROM mcr.microsoft.com/devcontainers/base:bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        shellcheck \
        jq \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*