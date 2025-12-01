<!---
  Copyright 2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Core concepts

This page illustrates the core concepts of Edgehog's container management system.

## Images

## Image credentials

Image credentials provide authentication for pulling container images from private registries. Edgehog's authentication system maps directly to the [Docker Engine API authentication mechanism](https://docs.docker.com/reference/api/engine/version/v1.51/#section/Authentication).

### How Image Credentials Work

- **Centralized management**: Credentials are [managed directly](./image_credentials_management.md) in Edgehog, allowing administrators to securely store registry authentication details
- **Contextual transmission**: Credentials are **not stored on the device**. Instead, they are sent to the device only when needed during [container creation](./applications_management.md#container-creation)
- **Docker-compatible format**: Credentials consist of a username and password (or token), following the standard Docker authentication format
- **Immutable after creation**: Credentials cannot be modified once created. To change credentials, create a new set and delete the old one

### Credential Components

Each credential contains:

- **Label**: A user-defined identifier for managing credentials in the Edgehog UI (e.g., `Production Registry`, `GitHub Packages`). This label is not sent to the device
- **Username**: The registry username used for authentication
- **Password**: The registry password or access token used for authentication

### Usage Example

When creating a container in a release, you can associate image credentials with an image that requires authentication. During deployment, Edgehog forwards the credentials to the device, allowing it to pull the image from the private registry.

For detailed information on managing credentials, see the [Image Credentials Management](./image_credentials_management.md) page.

## Volumes

## Networks

## Containers

## Release

## Applications

## Deployments
