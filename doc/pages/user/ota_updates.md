<!---
  Copyright 2022-2023 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# OTA Updates

Edgehog provides an OTA update mechanism that allows remotely updating devices. The OTA update
mechanism is not tied to a specific platform and can be used on any [Edgehog
runtime](device_sdks_runtime.html) which implements the
[`io.edgehog.devicemanager.OTARequest`](astarte_interfaces.html#io-edgehog-devicemanager-otarequest-v1-0),
[`io.edgehog.devicemanager.OTAEvent`](astarte_interfaces.html#io-edgehog-devicemanager-otaevent-v0-1)
and
[`io.edgehog.devicemanager.BaseImage`](astarte_interfaces.html#io-edgehog-devicemanager-baseimage-v0-1)
interfaces.

OTA Concepts are detailed in the [Core Concepts](core_concepts.html#ota-concepts) page, this guide
presents some of the operations which can be performed using Edgehog.

## Managed OTA Updates

Edgehog provides a mechanism to roll-out OTA updates to devices automatically, based on their System
Model and their membership to specific groups.

The sections below detail the operations that have to be performed to use managed OTA Updates.

### Creating a Base Image Collection

The first step to start using the OTA functionalities of Edgehog is creating at least one Base Image
Collection. The Base Image Collection will be tied to a specific System Model, which has to be
selected during the creation.

When creating a Base Image Collection, the following information must be provided

- Name: the display name of the Base Image Collection.
- Handle: an handle matching the `^[a-z][a-z\d\-]*$` regular expression.
- System Model ID: the ID of the System Model this Base Image Collection will be associated with.

A new Base Image Collection should be created for each group of Images implementing different
functionalities or implementing the same functionalities on different hardware.

### Uploading a Base Image

Once a new Base Image is baked, it can be uploaded into a specific Base Image Collection.

When uploading a Base Image, the following information must be provided:

- Version: a version number following the [Semantic Versioning](https://semver.org) spec. The
  version number must be unique.
- Release Display Name (optional): a localized user-friendly name for the release.
- Description (optional): a localized description of the content of the Base Image.
- Supported starting versions (optional): a [Version Requirement](core_concepts.html#version-requirement)
  that the Device must satisfy with its current Base Image to be updated with this Base Image.
  If a Device that does not satisfy the requirement is included in an Update Campaign
  that uses this Base Image, the result of the [OTA Operation](core_concepts.html#ota-operation) is an error.

Some information can be automatically filled in if the Base Image can be parsed by one of the
[supported Base Image parsers](#supported-base-image-parsers). Other than that, users are free to
use whatever format they choose for the artifact that will be pushed towards the device, provided
the Device is able to handle it.

When you upload a new Base Image in a Base Image Collection, no update is pushed towards devices,
the Base Image is just uploaded in Edgehog's storage. To start pushing updates towards devices, an
[Update Campaign](#creating-an-update-campaign) must be created.

#### Supported Base Image parsers

Base Image parsers are not implemented yet. As soon as they are implemented, this section will be
populated with the supported formats.

### Creating an Update Channel

Before creating the first Update Campaign, at least an Update Channel must be created.

The first Update Channel is automatically marked as the default* one. All Devices that are not
assigned to any other Update Channel will be implicitly assigned to this one.

*_The default Update Channel feature is planned for a future release_

When creating an Update Channel, the following information must be provided

- Name: the display name of the Update Channel
- Handle: an handle matching the `^[a-z][a-z\d\-]*$` regular expression.
- Target Groups (optional): a list of [groups](groups.html) containing Devices which will
  automatically get assigned to this Update Channel.

Note that only a single Update Campaign can be active for a given Update Channel and System Model
combination. This means that to implement A/B beta testing, two separate Update Channels (e.g.
`beta-a` and `beta-b`) must be created.

A group can be associated only with a single Update Channel. To change the auto-assignment of a
specific group from an Update Channel to another, the group must be removed from the previous Update
Channel and then added to the new one.

Note that even if a group can be associated with a single Update Channel, conflicts can still arise
(since two different groups can include the same Device). Since the set of Devices that receive
updates from an Update Channel is snapshotted when an Update Campaign is created, if there are
conflicts the Device will always receive the update from the most recent Update Campaign.

### Creating an Update Campaign

To actually push updates towards Devices, an Update Campaign must be started. Note that an Update
Campaign can only send updates for the same Base Image Collection, and special operations (like
converting a Device from a System Model to another) must always be done with a [Manual OTA
Update](#manual-ota-updates).

When creating an Update Campaign, the following information must be provided

- Base Image: the target Base Image for the Update Campaign.
- Update Channel: the target Update Channel for the Update Campaign.
- [Roll-out Mechanism](#roll-out-mechanism) properties.

Once created, the Update Campaign will start rolling out updates towards the devices, and its
progress can be checked from the Edgehog Dashboard or through Edgehog GraphQL API.

Note that the campaign will "snapshot" the Devices belonging to the Update Channel when it's
started, and will target only those. If additional Devices are added to the Update Channel (either
manually or automatically via auto-assignment) _after_ the Update Campaign is created, they won't
receive the Base Image and will require a separate campaign to be started.

Only a single Update Campaign can be started for a given System Model and Update Channel
combination, so creating a new Update Campaign while another one is already running will implicitly
cancel* the old one. This means that Devices that didn't yet receive the Base Image of the old Update
Campaign will directly receive the new one, without any intermediate step.

*_Implicit Cancellation feature is planned for a future release_

#### Roll-out mechanism

Here are the currently supported Roll-out Mechanisms and their properties

##### `push`

This Roll-out mechanism pushes the update towards the device unconditionally. This can be used to
provide automatic updates where the user should not have the choice of refusing the update.

The properties of this Roll-out Mechanism are

- Max Pending Operations: the maximum number of pending [OTA Operations](core_concepts.html#ota-operation).
  The Update Campaign will have at most this number of OTA Operations that are started 
  but not yet finished (either successfully or not).
- Max Failures: the maximum percentage of failures allowed over the number of total targets. If the failures 
  exceed this threshold, the Update Campaign terminates with a failure.
- Request Retries: the number of times an update must be retried on a specific Device before considering it
  a failure. Note that the update is retried only if the OTA Request doesn't get acknowledged from the device.
- Request Timeout: the timeout (in seconds) to wait before considering an OTA Request lost (and possibly retry).
- Allow downgrade (optional): when checked allows downgrading a Device which is currently using a later version
  of the Base Image.

##### `optional`*

*_The Optional rollout mechanism is planned for a future release_

This Roll-out mechanism just pushes a message towards the Device informing that an update is
available. The update is downloaded to the device only after the user accepts the update. The update
is not required to be pushed immediately, to provide a backpressure mechanism if many users accept
the update at the same time.

## Manual OTA Updates

As an escape hatch, it's always possible to manually update a Device from its page on the Edgehog
dashboard (or using the Edgehog GraphQL API).

Note that Manual OTA Updates do not perform any check on the System Model, so they can effectively
be used to change the System Model of a Device. This also means that the user must exercise
particular attention to avoid bricking a Device, if the Device does not implement the necessary
safety checks.
