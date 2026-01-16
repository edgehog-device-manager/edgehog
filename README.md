<!---
  Copyright 2021,2022 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Edgehog

**Edgehog** is an Open Source Device Manager Platform designed to manage the entire lifecycle of your IoT device fleet. Built with **Elixir** and powered by **Astarte**, it provides a robust, scalable, and secure environment for maintaining connected embedded systems.

From hardware-independent monitoring to remote container management, Edgehog allows you to focus on your core application while it handles the complexities of fleet orchestration.

---

## 🚀 Key Features

- **Device Fleet Management:** Maintain a bird's-eye view of your entire fleet. Access real-time status, hardware info, OS versions, and telemetry data.
- **Over-the-Air (OTA) Updates:** Create and manage software update campaigns. Filter devices by models or tags to roll out updates safely and efficiently.
- **Docker Application Management:** Remotely deploy, start, stop, and update Docker containers on your devices.
- **Geolocation:** Automatically geolocate devices using GPS data, nearby WiFi signals, or IP-based location services.
- **GraphQL API:** Fully programmable platform. Every action available in the frontend can be performed via our GraphQL API.

Edgehog is built on top of [Astarte](https://docs.astarte-platform.org/), the Open Source IoT platform. It uses Astarte for secure device communication (MQTT) and data orchestration.

## 📦 Getting Started

### Deployment (Kubernetes)

Edgehog is designed as a cloud-native application. The recommended way to deploy it in production is via **Kubernetes**.

1. **Images:** Container images are available on [Docker Hub](https://hub.docker.com/u/edgehogdevicemanager).
2. **Setup:** Refer to the [Deployment Guide](https://docs.edgehog.io/0.10/deploying_with_kubernetes.html) for detailed instructions on setting up secrets, S3-compatible storage, and ingress.

### Local Development

To run Edgehog locally for development:

#### Prerequisites

- Elixir 1.19.5 and OTP 28
  > Hint: use [asdf](https://asdf-vm.com/guide/getting-started.html) to install them
  >
  > ```sh
  > asdf plugin add erlang
  > asdf plugin add elixir
  > asdf plugin add node
  > asdf install
  > ```
- PostgreSQL 13+
- A local or remote Astarte instance

#### Setup

```bash
# Clone the repository
git clone https://github.com/edgehog-device-manager/edgehog.git
cd edgehog

# requires `just` command runner. Takes care of running astarte and postgres trough docker.
just provision-tenant
```

## 📱 Device Support

To connect your devices to Edgehog, use one of our supported runtimes:

- **[Edgehog Device Runtime (Rust)](https://github.com/edgehog-device-manager/edgehog-device-runtime):** Portable middleware for Linux-based systems.
- **[Edgehog ESP32 (C)](https://github.com/edgehog-device-manager/edgehog-esp32-device):** Component for ESP-IDF.
- **[Edgehog Zephyr (C)](https://github.com/edgehog-device-manager/edgehog-zephyr-device):** Support for Zephyr OS.

## 📖 Documentation

Full documentation, including API references and tutorials, is available at:
👉 **[docs.edgehog.io](https://docs.edgehog.io/)**

## 🤝 Contributing

We welcome contributions! Whether it’s bug reports, feature requests, or pull requests, please check out our [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## 📄 License

Edgehog is released under the **Apache 2.0 License**. See the [LICENSE](LICENSE) file for more details.

---

_Built with ❤️ by the Edgehog Community and [SECO](https://www.seco.com)._
