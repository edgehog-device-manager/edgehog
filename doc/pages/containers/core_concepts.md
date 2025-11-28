<!---
  Copyright 2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Core concepts

This page illustrates the core concepts of Edgehog's container management system.

## Images

## Image credentials

Image credentials are used to authenticate against container registries when pulling images. In Edgehog, credentials are:

- **Managed directly** in the [credentials management section](./image_credentials_management.md) of the application. This allows administrators to securely store and update registry credentials.
- **Sent to the device contextually** when deploying a container. Credentials are forwarded only when needed, during [container creation](./applications_management.md#container-creation) in the application management workflow.
- **Securely stored and forwarded** to the device. Edgehog stores credentials securely for management and transmission, and forwards them as-is to the device for use by the Docker engine when needed.

#### Example: Valid Credentials

Credentials must follow the format expected by the Docker Engine API, with an additional `label` field supported by Edgehog:

- The `label` field is a user-defined string that helps identify or describe the credentials (e.g., `Production Registry`, `Test Registry`). It is not sent to the device, but is used in the UI and API for easier management and selection of credentials.

![Image credentials Screenshot](assets/image_credentials.png)

## Volumes

## Networks

## Containers

## Release

## Applications

## Deployments
