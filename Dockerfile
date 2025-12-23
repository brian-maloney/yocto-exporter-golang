# Use a Go builder image
FROM golang:1.23 AS builder

ARG YOCTOLIB_VERSION=v2.1.6320

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libusb-1.0-0-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone the Yoctopuce library
RUN git clone --depth 1 --branch ${YOCTOLIB_VERSION} https://github.com/yoctopuce/yoctolib_cpp.git

# Copy the project files (yoctolib_cpp is excluded via .dockerignore)
COPY . .

# Set cache directories to local app folder to avoid permission issues if any
ENV GOMODCACHE=/app/.cache/go-mod
ENV GOCACHE=/app/.cache/go-build

# Build argument for version injection
ARG VERSION=dev

# Build the binary
RUN make VERSION=${VERSION} && strip yocto-exporter

# Final stage: minimal runtime image
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libusb-1.0-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/
COPY --from=builder /app/yocto-exporter .

EXPOSE 8000
CMD ["./yocto-exporter"]
