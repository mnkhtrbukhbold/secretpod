FROM docker:29.8.0-cli
RUN apk add --no-cache python3
LABEL org.opencontainers.image.source="https://github.com/mnkhtrbukhbold/secretpod"
WORKDIR /__secretpod_manager
COPY scripts/host.py scripts/host.sh scripts/host.ps1 scripts/
COPY compose.yaml ./
COPY deploy/Caddyfile deploy/Caddyfile
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 HOME=/tmp
ENTRYPOINT ["python3", "/__secretpod_manager/scripts/host.py"]
