FROM alpine:3.13.5 AS builder
WORKDIR /app
RUN wget -O qbittorrent-nox https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.6.2_v2.0.9/x86-qbittorrent-nox

FROM ghcr.io/hotio/qbittorrent:release-4.6.2
COPY --from=builder --chmod=755 /app/qbittorrent-nox /app/qbittorrent-nox