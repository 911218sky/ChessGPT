# syntax=docker/dockerfile:1.7

ARG FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:stable
ARG NGINX_IMAGE=nginx:1.27-alpine

FROM ${FLUTTER_IMAGE} AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
ARG CHESS_AI_WEB_LLM_PROXY_BASE_URL=
ARG CHESS_AI_DEFAULT_LLM_ENABLED=false
ARG CHESS_AI_DEFAULT_LLM_MODEL=gpt-5.5
RUN flutter build web --release \
  --dart-define "CHESS_AI_WEB_LLM_PROXY_BASE_URL=${CHESS_AI_WEB_LLM_PROXY_BASE_URL}" \
  --dart-define "CHESS_AI_DEFAULT_LLM_ENABLED=${CHESS_AI_DEFAULT_LLM_ENABLED}" \
  --dart-define "CHESS_AI_DEFAULT_LLM_MODEL=${CHESS_AI_DEFAULT_LLM_MODEL}"

FROM ${NGINX_IMAGE} AS runtime

ENV NGINX_LLM_PROXY_TARGET=https://www.inroi.shop/v1/ \
    NGINX_LLM_PROXY_AUTHORIZATION=

COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz >/dev/null || exit 1
