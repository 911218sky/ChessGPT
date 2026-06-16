# syntax=docker/dockerfile:1.7

ARG FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:stable
ARG NGINX_IMAGE=nginx:1.27-alpine

FROM ${FLUTTER_IMAGE} AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
ARG CHESSGPT_WEB_LLM_PROXY_BASE_URL=
ARG CHESSGPT_DEFAULT_LLM_ENABLED=false
ARG CHESSGPT_DEFAULT_LLM_MODEL=codex-auto-review
RUN flutter build web --release \
  --dart-define "CHESSGPT_WEB_LLM_PROXY_BASE_URL=${CHESSGPT_WEB_LLM_PROXY_BASE_URL}" \
  --dart-define "CHESSGPT_DEFAULT_LLM_ENABLED=${CHESSGPT_DEFAULT_LLM_ENABLED}" \
  --dart-define "CHESSGPT_DEFAULT_LLM_MODEL=${CHESSGPT_DEFAULT_LLM_MODEL}" \
  && BUILD_ID="$(date +%s)" \
  && sed -i "s/flutter_bootstrap.js/flutter_bootstrap.js?v=${BUILD_ID}/" build/web/index.html \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=${BUILD_ID}\"/" build/web/flutter_bootstrap.js

FROM ${NGINX_IMAGE} AS runtime

ENV NGINX_LLM_PROXY_TARGET=https://www.inroi.shop \
    NGINX_LLM_PROXY_HOST=www.inroi.shop \
    NGINX_LLM_PROXY_AUTHORIZATION=

COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz >/dev/null || exit 1
