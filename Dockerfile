# Build everything from source; no generated local assets are included.
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
RUN flutter build web --release --no-web-resources-cdn
WORKDIR /src/secretpod/secretpod_server
RUN dart build cli --target bin/main.dart --output build

FROM debian:trixie-slim
LABEL org.opencontainers.image.source="https://github.com/mnkhtrbukhbold/secretpod"
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl libstdc++6 && rm -rf /var/lib/apt/lists/* && groupadd --gid 10001 secretpod && useradd --uid 10001 --gid 10001 --no-create-home secretpod && mkdir /data && chown secretpod:secretpod /data
WORKDIR /app
COPY --from=build /src/secretpod/secretpod_server/build/bundle/ ./
COPY --from=build /src/secretpod/secretpod_server/config/ config/
COPY --from=build /src/secretpod/secretpod_flutter/build/web/ web/app/
USER 10001:10001
EXPOSE 8080 8082
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=6 CMD curl --fail --silent http://127.0.0.1:8082/healthz > /dev/null || exit 1
ENTRYPOINT ["./bin/main", "--mode", "production"]
