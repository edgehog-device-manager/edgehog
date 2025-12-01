<!---
  Copyright 2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Core concepts

THis page illustrates the core concepts of Edgehog's container management system.

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

## Volumes

## Networks

## Containers

## Release

## Applications

## Deployments
