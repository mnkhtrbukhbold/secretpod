# Build from allowlisted source only. No local vault or generated web bundle
# enters this image. Keep the Flutter toolchain aligned with ../Dockerfile.
FROM dart:3.13.5 AS build
RUN apt-get update && apt-get install -y --no-install-recommends git curl unzip xz-utils ca-certificates && rm -rf /var/lib/apt/lists/*
ARG FLUTTER_REVISION=abaf9c523780a608bd46686fd5e53740a07077f8
RUN git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git /opt/flutter && test "$(git -C /opt/flutter rev-parse HEAD)" = "$FLUTTER_REVISION"
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter config --no-analytics && flutter precache --web
WORKDIR /src/secretpod
COPY secretpod/pubspec.yaml secretpod/pubspec.lock ./
COPY secretpod/secretpod_client/ secretpod_client/
COPY secretpod/secretpod_server/ secretpod_server/
COPY secretpod/secretpod_flutter/ secretpod_flutter/
RUN flutter pub get --enforce-lockfile
WORKDIR /src/secretpod/secretpod_flutter
RUN flutter build web --release --no-web-resources-cdn --target lib/main_demo.dart --pwa-strategy=none

# The runtime has no API server, database, encryption keys, or private data.
FROM caddy:2.11.2-alpine
LABEL org.opencontainers.image.source="https://github.com/mnkhtrbukhbold/secretpod"
COPY deploy/demo.Caddyfile /etc/caddy/Caddyfile
COPY --from=build /src/secretpod/secretpod_flutter/build/web/ /srv/
ENV PORT=8080
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 CMD wget -q -O /dev/null "http://127.0.0.1:${PORT:-8080}/healthz" || exit 1
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
