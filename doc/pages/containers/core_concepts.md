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

Volumes represent Docker-managed storage that persists data independently of the container lifecycle. 
They are created and managed directly through the application's [volumes management section](./volume_management.md).

### Volume Structure
Each volume consists of the following fields:
- **Label**: A user-defined name used to identify the volume within the application
- **Driver**: Specifies which Docker volume driver should be used. The default driver is usually local
- **Options**: A set of key-value pairs that provide custom configuration for the selected driver

### Volume Purpose and Relationship to Containers
While volumes can exist independently, a volume is not meaningful unless it is attached to at least one [container](core_concepts-2.html#containers).

The purpose of a volume is to provide persistent storage for containerized applications, so it becomes valuable only when linked to a container’s filesystem.

### Volumes vs. Bind Mounts
Docker provides two main ways to persist data: volumes and bind mounts, and it's important to understand the difference.

With a **bind mount**, a file or directory from the host machine is mounted directly into the container.
With a **volume**, Docker creates a new directory inside its own managed storage area on the host and takes full responsibility for managing its contents.

## Networks

In Edgehog, networks correspond directly to Docker networks. They are [managed through Edgehog](./network_management.md), allowing users to create reusable network specifications that can be referenced by multiple containers during the deployment process.

For each network, Edgehog allows you to configure:

- **Label** – A human-readable identifier for the network.
- **Driver** – The Docker network driver to use (e.g., `bridge`, `overlay`).
- **Options** – A set of driver-specific configuration parameters.
- **Enable IPv6** – Whether the network should support IPv6 addressing.
- **Internal** – Whether the network should be isolated from external access.

For more detailed information on creating and managing networks, refer to the [Network Management](./network_management.md) page.

## Containers

## Releases

Releases are an Edgehog concept which represent a set of containers that provide a useful way of organizing a scope. They follow semantic versioning, so that the user is able to know when a specific update can contain breaking changes. Releases are managed directly (take a look at [Release creation process](./applications_management.md#release-creation-process)).

There are no restrictions on what can happen underneath as they are just a logical framework to organize different versions of the same application. For example, release `1.2.9` of an application can contain a `backend` container and a `postgres` database, release `2.0.0` an upgraded version of the `backend` and an instance of `scylla db`.

### Release Components

Each release contains:

- **Version**: a version number following the [Semantic Versioning](https://semver.org) spec. The version number must be unique.
- **Supported System Models**: a list of supported system models that specify multiple types of devices that can be compatible: if some required system models are specified by the release, the device needs to match one of those. The idea is that different releases of the same app may have different compatibility requirements.
- **Containers**: a set of containers (see [Containers](./applications_management.md#containers)).

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

Deployments are a core Edgehog concept that link devices to specific application releases. Unlike Docker, which has no equivalent concept, deployments in Edgehog represent the operational unit for managing containerized workloads on individual devices.

### Key Characteristics

- **Device-Release binding**: A deployment connects a specific device to a particular release from an application
- **Centralized management**: Deployments are [managed directly](../user/devices.md) through the device interface in Edgehog
- **Action-oriented**: Deployments are the minimum unit on which users can execute lifecycle operations
- **Stateful tracking**: Each deployment tracks the current state of the release on the device

### Deployment Actions

- ![Start action](assets/deployments_start.png) **Start**: Launch the containers defined in the deployed release
- ![Stop action](assets/deployments_stop.png) **Stop**: Halt running containers without removing them
- ![Upgrade action](assets/deployments_upgrade.png) **Upgrade**: Deploy another specified release from the same application (the old version is still kept)
- ![Redeploy action](assets/deployments_redeploy.png) **Redeploy**: Re-create and restart the deployment, useful when resources are not ready or in an inconsistent state
- ![Delete action](assets/deployments_delete.png) **Delete**: Remove the deployment and all associated containers from the device

![Deployment details](assets/deployments_info.png) Additionally, users can open a dedicated deployment details page to view comprehensive information about the deployment, including:

- Current container status and runtime configurations
- Events history
- Network and volume bindings

### How Deployments Work

When you deploy a release to a device, Edgehog creates a deployment that binds that device to the specific release configuration. The device receives instructions to pull images, create volumes and networks, and start containers according to the release specification.

All container lifecycle management on a device happens through its deployment. This abstraction allows Edgehog to maintain consistent control over containerized workloads across your device fleet, regardless of the underlying container runtime.
