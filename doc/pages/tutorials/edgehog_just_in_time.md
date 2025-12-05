<!---
  Copyright 2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Edgehog Just in Time

## Introduction

Why spend 5 minutes setting up Edgehog when you can do it **just** right? This tutorial will guide you through setting up Edgehog using the `justfile`.

## Prerequisites

Before we get started, make sure you have the following tools installed:

- **Git**: For cloning repositories
- **Docker**: For running containers
- **Docker Compose**: For orchestrating services
- **astartectl**: For managing Astarte ([installation guide](https://github.com/astarte-platform/astartectl#installation))
- **just**: The command runner that makes this all possible. You can install it using [asdf](https://asdf-vm.com/), your system package manager, or follow the [official installation guide](https://github.com/casey/just#installation)
- **Rust toolchain** (optional, only needed for connecting devices): You can install it using [asdf](https://asdf-vm.com/), [rustup](https://rustup.rs/), or your preferred method

## Clone the Edgehog Repository

First, clone the Edgehog repository and navigate into it:

```sh
$ git clone https://github.com/edgehog-device-manager/edgehog && cd edgehog
```

## Discover Available Commands

The beauty of `just` is its discoverability. See all available commands with:

```sh
$ just --list
```

Or simply:

```sh
$ just help
```

This will show you all the recipes (tasks) available in the justfile, nicely organized by category.

## Setting Up Your Environment

To set up the complete Edgehog stack with Astarte and a test tenant, run:

```sh
$ just provision-tenant
```

This single command will:

1. ✅ Check system prerequisites
2. 🔧 Configure system settings (adjusting `aio-max-nr` if needed)
3. 🌟 Clone and initialize Astarte
4. 🏠 Create an Astarte `test` realm
5. 🚀 Start Edgehog services
6. 👤 Create a test tenant in Edgehog
7. 🌐 Automatically open the dashboards in your browser

Sit back, relax, and watch the magic happen!

> **Other setup options:** If you need more granular control, check out the available commands with `just --list` or `just help`.

## Accessing the Dashboards

After provisioning, your dashboards should open automatically. If not, or if you closed them, just run:

```sh
$ just open-dashboards
```

This will open:

- **Astarte Dashboard**: [`http://dashboard.astarte.localhost`](http://dashboard.astarte.localhost)
- **Edgehog Dashboard**: [`http://edgehog.localhost`](http://edgehog.localhost)

You'll be automatically logged in with the appropriate JWT tokens!

## Connecting a Device

Want to see Edgehog in action with a real (simulated) device? It's just one command away:

```sh
$ just connect-device
```

This will:

1. 🔍 Check Rust prerequisites
2. 📦 Clone the Edgehog Device Runtime repository
3. 📝 Register a new device with Astarte
4. ⚙️ Generate the device configuration
5. 🚀 Start the device runtime

Your device will start sending telemetry data to Edgehog. Watch it appear in the Edgehog dashboard!

> **Note:** If you encounter issues with the device runtime, check the [OS requirements documentation](https://github.com/edgehog-device-manager/edgehog-device-runtime/blob/main/doc/os_requirements.md) for system-specific setup details.

### Reconnecting the Same Device

Already have a device configured but want to restart it with a clean state? Use:

```sh
$ just reconnect-device
```

This command:

- ✅ Uses your existing device configuration (no re-registration needed)
- 🧹 Cleans device state (`.store/` and `.updates/` directories)
- 🚀 Starts the device runtime with existing build artifacts
- ⚡ Fast startup - no compilation or registration overhead!

If no device is configured yet, it will automatically run `just connect-device` to set everything up.

### Connecting a New Device

Want to test with multiple devices? Register and connect a new device with:

```sh
$ just new-device
```

This command:

- 📝 Registers a new device with Astarte (new device ID and credentials)
- 🧹 Cleans previous device state
- ⚙️ Generates fresh device configuration
- 🚀 Starts the device runtime
- ⚡ Reuses compiled runtime - faster than full `connect-device`!

This is perfect for testing scenarios with multiple devices without waiting for a full recompilation.

> **Running Multiple Devices**: You can run multiple devices simultaneously by using separate terminals! Once a device is running, it has its own runtime context in memory. Simply open a new terminal, run `just new-device` to register a different device (which overwrites the config file), and both devices will run in parallel. Each device maintains its own state since they have unique device IDs.

> **Important**: Remember that all simulated devices are running on the same physical hardware (your PC/laptop). Features that require exclusive access to the same hardware resources may conflict or fail when running multiple devices simultaneously.

## Development Workflows

### Running Backend in Development Mode

Want to work on the Edgehog backend? Start it in development mode:

```sh
$ just dev-backend
```

This will:

- ✅ Ensure Astarte is running
- 🐘 Start supporting services (PostgreSQL, MinIO, Registry)
- 🔥 Run the backend with `mix phx.server` for hot reloading
- 🌐 Make the API available at `http://localhost:4000`

### Running Frontend in Development Mode

To work on the frontend:

```sh
$ just dev-frontend
```

This starts the Vite dev server with hot module replacement at `http://localhost:5173`.

### Running Both in Parallel

Open two terminal windows and run:

```sh
# Terminal 1
$ just dev-backend

# Terminal 2
$ just dev-frontend
```

## Monitoring Your Services

### Check Service Status

Want to see what's running?

```sh
$ just status
```

This shows:

- All running Docker containers
- Health check status for all services

### View Logs

To tail logs from all Edgehog services:

```sh
$ just logs
```

Or just Astarte services:

```sh
$ just logs-astarte
```

## Cleaning Up

### Tear Down Everything

When you're done and want to clean up completely:

```sh
$ just deprovision-tenant
```

This removes:

- All Edgehog services and volumes
- All Astarte services and volumes
- Generated files and directories
- Device runtime files

### Keep Astarte, Remove Edgehog

If you want to keep Astarte running but clean up Edgehog and device runtime:

```sh
$ just deprovision-edgehog
```

This is useful when you want to restart Edgehog fresh while keeping your Astarte realm intact.

## Troubleshooting

### Services Not Starting

Check the status first:

```sh
$ just status
```

If services are down, check the logs:

```sh
$ just logs
```

## Conclusion

With `just`, setting up Edgehog is... well, just easy! No more remembering complex Docker commands or multi-step setup procedures. Just run `just provision-tenant` and you're ready to manage your IoT devices.

Remember: when in doubt, `just help` will show you the way!

---

**Pro tip**: You can create your own custom recipes in the justfile. It's just a regular text file with a simple syntax. Check out the [just documentation](https://just.systems) to learn more.
