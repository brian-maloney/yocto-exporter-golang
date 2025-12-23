# Yocto Exporter (Golang Version)

A Prometheus exporter for Yoctopuce sensors, written in Go. This project is a Go-based implementation of the original [Python Yocto Exporter](https://github.com/brian-maloney/yocto-exporter).

## Features

- **Multi-Sensor Support**: Automatically discovers all supported Yoctopuce sensors (Temperature, Humidity, Pressure, Light, etc.).
- **Multi-Device Support**: Correctly handles multiple identical sensors on the same or different devices using labels for `hardwareId`.
- **Unit Overrides**: Flexible unit overriding via command line to ensure compatibility with existing deployments or to fix encoding issues.
- **One-shot Mode**: Output metrics once to stdout and exit—perfect for debugging and automation scripts.
- **Dockerized**: Multi-stage Docker builds provide a minimal runtime image (~25MB).
- **High Performance**: Uses the native Yoctopuce C++ library via `cgo` for efficient device communication.
- **Version Reporting**: Includes a `-version` flag to track the specific build and git commit.

## Installation

### Prerequisites

- Go 1.23 or later
- A C++ compiler (gcc/g++)
- `libusb-1.0` development headers

### From Source

```bash
# Clone the repository and its submodules
git clone --recursive https://github.com/brian-maloney/yocto-exporter-golang.git
cd yocto-exporter-golang

# Build the binary
make
```

### Docker

```bash
docker build -t yocto-exporter .
```

## Usage

```bash
./yocto-exporter [flags]
```

### Flags

| Flag | Description | Default |
| :--- | :--- | :--- |
| `-hub-url` | Yoctopuce Hub URL (e.g., `usb`, `127.0.0.1:4444`, `192.168.1.10`) | `usb` |
| `-listen-address` | The address to listen on for HTTP requests | `:8000` |
| `-metrics-path` | Path under which to serve metrics | `/metrics` |
| `-override-unit` | Override unit for a specific functionId (e.g., `temperature='C`). Can be repeated. | |
| `-oneshot` | Run once and output metrics to stdout, then exit | `false` |
| `-version` | Print version information and exit | `false` |

### Examples

**Normal operation:**
```bash
./yocto-exporter -hub-url usb -listen-address :8000
```

**Overriding temperature units for legacy compatibility:**
```bash
./yocto-exporter -override-unit temperature="'C"
```

**Testing sensor discovery:**
```bash
./yocto-exporter -oneshot
```

**Running via Docker:**
```bash
docker run --rm -p 8000:8000 yocto-exporter:latest -hub-url usb
```

## Metrics

The exporter exposes metrics for every sensor function discovered. The metric name corresponds to the `functionId` of the sensor.

```text
# HELP temperature Current temperature reading
# TYPE temperature gauge
temperature{hardwareId="METEOMK1-D6150.temperature",unit="'C"} 19.14

# HELP humidity Current humidity reading
# TYPE humidity gauge
humidity{hardwareId="METEOMK1-D6150.humidity",unit="% RH"} 49.1
```

## Contributing

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes (`git commit -m 'Add some amazing feature'`).
4. Push to the branch (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

## License

This project is licensed under the [GPLv3 License](LICENSE) - see the LICENSE file for details.

---
*Based on the original work at [brian-maloney/yocto-exporter](https://github.com/brian-maloney/yocto-exporter).*
