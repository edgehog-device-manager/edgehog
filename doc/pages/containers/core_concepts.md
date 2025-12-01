<!---
  Copyright 2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Core concepts

This page illustrates the core concepts of Edgehog's container management system.

## Images

Images in Edgehog are not managed directly by the platform. Instead, Edgehog treats images as external references that are passed to the device’s container runtime (such as Docker or Podman). Edgehog does not store, pull or validate images, it simply records the image reference string provided in a container definition.

### Image Reference Format

The image reference represents the name of the image to pull.
It follows the pattern:

```
[registry-host[:port]/][image-repo/]image-name[:(tag|digest)]
```

### Image Reference Examples

#### Basic Examples

```
nginx
redis
python
```

#### With Explicit Tags

```
nginx:1.27
python:3.12-alpine
```

#### With Image Repository

```
library/ubuntu:24.04
myorg/backend-service:1.5.0
```

#### With Custom Registry Host

```
registry.example.com/myapp/web:2.3.1
docker.mycompany.local/backend:latest
```

#### With Registry Host and Port

```
registry.example.com:5000/myteam/processor:dev
10.1.2.3:5000/custom/image:1.0.0
```

#### Digest-Based References

```
ubuntu@sha256:5f15a489d63a0e...
nginx@sha256:0f472fa682c7a...
registry.example.com/myapp/api@sha256:8a12bf9c4dfc2...
```

### Image Deduplication

Edgehog **treats every image reference as unique**, even if multiple references resolve to the **same underlying image digest**.

For example, all of the following represent _different images_ to Edgehog:

- `ubuntu:latest`
- `ubuntu:24.04`
- `ubuntu@sha256:5f15a489d63a0e...`

Edgehog does not attempt to resolve tags to digests or detect when different references point to the same image. It always relies exclusively on the user-provided reference.

#### Example: Image Reference Clash

A _clash_ happens when two different references point to the same actual image digest. This is uncommon but can occur, especially with rolling or moving tags like `latest`.

For example, in the official Ubuntu Docker image:

```
ubuntu:latest  → sha256:5f15a489d63a0e...
ubuntu:24.04   → sha256:5f15a489d63a0e...
```

Even though both tags point to the **same digest**, Edgehog treats them as **two distinct images**, because their reference strings differ.

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

Applications are a core Edgehog concept that organize container deployments across devices. Unlike Docker, which has no equivalent concept, applications in Edgehog provide a structured way to manage container lifecycle and updates.

### Key Characteristics

- **Centralized management**: Applications are [managed directly](./applications_management.md) in Edgehog, providing a single point of control for container deployments
- **Release-based structure**: Each application consists of an ordered list of releases, where each release defines a specific configuration of containers, volumes, and networks
- **Device-agnostic**: Devices do not have a direct notion of applications. Instead, they receive individual releases to deploy
- **Upgrade-driven workflow**: Devices can be instructed to perform upgrades, transitioning from one release to another within an application

### How Applications Work

Applications serve as logical groupings that track the evolution of your containerized workloads. When creating an application, you only need to provide a name and description. The actual container definitions are added later through releases.

When you want to deploy containers to a device, you select a specific release from an application. The device then deploys that release configuration without awareness of the broader application context.

For detailed information on creating and managing applications, see the [Applications Management](./applications_management.md) page.

## Deployments
