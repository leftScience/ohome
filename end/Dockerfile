# syntax=docker/dockerfile:1.6

FROM golang:1.25-alpine AS builder

WORKDIR /app

ARG VERSION=0.0.1
ARG COMMIT=dev
ARG BUILD_TIME=
ARG CHANNEL=stable
ARG RUNTIME_VERSION=runtime-dev

ENV CGO_ENABLED=0
# 自动下载所需 Go 工具链版本（go.mod 要求 1.25）
ENV GOTOOLCHAIN=auto
# 使用国内代理拉取工具链和依赖，避免访问被阻断
ENV GOPROXY=https://goproxy.cn,direct

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -ldflags="-X 'ohome/buildinfo.Version=${VERSION}' -X 'ohome/buildinfo.Commit=${COMMIT}' -X 'ohome/buildinfo.BuildTime=${BUILD_TIME}' -X 'ohome/buildinfo.Channel=${CHANNEL}'" -o /app/bin/ohome .
RUN go build -ldflags="-X 'ohome/buildinfo.Version=${VERSION}' -X 'ohome/buildinfo.Commit=${COMMIT}' -X 'ohome/buildinfo.BuildTime=${BUILD_TIME}' -X 'ohome/buildinfo.Channel=${CHANNEL}' -X 'ohome/buildinfo.RuntimeVersion=${RUNTIME_VERSION}'" -o /app/bin/ohome-launcher ./cmd/launcher

FROM alpine:3.19

WORKDIR /app

ARG VERSION=0.0.1
ARG DEFAULT_UPDATE_MANIFEST_URL=

ENV GIN_MODE=release
ENV PORT=18090
ENV UPDATE_UPDATER_BASEURL=http://127.0.0.1:18091
ENV UPDATE_UPDATER_TOKEN=ohome-local-updater
ENV UPDATE_MANIFESTURL=${DEFAULT_UPDATE_MANIFEST_URL}

# 创建配置/数据目录，默认配置和 sql 初始化文件随镜像一起拷贝
RUN apk add --no-cache ca-certificates tzdata && mkdir -p /app/bin /app/conf /app/data /app/log /app/sql /app/defaults

COPY --from=builder /app/bin/ohome /app/bin/server
COPY --from=builder /app/bin/ohome-launcher /app/launcher
COPY --from=builder /app/sql /app/sql
COPY --from=builder /app/conf/config.yaml /app/defaults/config.yaml
COPY docker-entrypoint.sh /app/docker-entrypoint.sh

RUN printf "%s" "$VERSION" > /app/bin/server.version && chmod +x /app/docker-entrypoint.sh /app/launcher /app/bin/server

EXPOSE 18090

CMD ["/app/docker-entrypoint.sh"]
