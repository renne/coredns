ARG DEBIAN_IMAGE=debian:stable-slim
ARG BASE=gcr.io/distroless/static-debian12:nonroot
ARG GOLANG_VERSION=1.25.5

# Builder stage - compile CoreDNS from source (for fork with custom plugins)
FROM --platform=$BUILDPLATFORM golang:${GOLANG_VERSION}-alpine AS builder
WORKDIR /build
RUN apk add --no-cache git make
COPY . .
ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64} make

# Capabilities stage
FROM --platform=$BUILDPLATFORM ${DEBIAN_IMAGE} AS build
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq update \
    && apt-get -qq --no-install-recommends install libcap2-bin
COPY --from=builder /build/coredns /coredns
RUN setcap cap_net_bind_service=+ep /coredns

FROM ${BASE}
COPY --from=build /coredns /coredns
USER nonroot:nonroot
# Reset the working directory inherited from the base image back to the expected default:
# https://github.com/coredns/coredns/issues/7009#issuecomment-3124851608
WORKDIR /
EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
