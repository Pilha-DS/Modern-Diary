# syntax=docker/dockerfile:1

ARG FLUTTER_VERSION=3.47.7

FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION
# Vazio usa a propria origem: o nginx do container faz proxy de /api para o servico "api".
ARG API_BASE_URL=""
# Dados do rodape; vazios caem no padrao definido em lib/src/core/config/app_info.dart.
ARG APP_AUTHOR_NAME
ARG APP_CONTACT_EMAIL
ARG APP_AUTHOR_PHONE
ARG APP_AUTHOR_SITE
ARG APP_VERSION

ENV FLUTTER_HOME=/opt/flutter \
    PATH=/opt/flutter/bin:$PATH

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ -C /opt \
 && git config --global --add safe.directory "$FLUTTER_HOME" \
 && flutter config --no-analytics \
 && flutter precache --web

WORKDIR /src

COPY packages/modern_diary_ui ./packages/modern_diary_ui
COPY app/pubspec.yaml app/pubspec.lock ./app/

WORKDIR /src/app
RUN flutter pub get

COPY app/lib ./lib
COPY app/web ./web
RUN flutter build web --release \
      --dart-define=API_BASE_URL="$API_BASE_URL" \
      --dart-define=APP_AUTHOR_NAME="$APP_AUTHOR_NAME" \
      --dart-define=APP_CONTACT_EMAIL="$APP_CONTACT_EMAIL" \
      --dart-define=APP_AUTHOR_PHONE="$APP_AUTHOR_PHONE" \
      --dart-define=APP_AUTHOR_SITE="$APP_AUTHOR_SITE" \
      --dart-define=APP_VERSION="$APP_VERSION"

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/app/build/web /usr/share/nginx/html

EXPOSE 80
