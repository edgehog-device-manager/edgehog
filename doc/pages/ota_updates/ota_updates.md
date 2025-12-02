<!---
  Copyright 2022-2023 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# OTA Updates

Edgehog provides an OTA update mechanism that allows remotely updating devices. The OTA update
mechanism is not tied to a specific platform and can be used on any [Edgehog
runtime](devices_and_runtime.html) which implements the
[`io.edgehog.devicemanager.OTARequest`](astarte_interfaces.html#io-edgehog-devicemanager-otarequest-v1-0),
[`io.edgehog.devicemanager.OTAEvent`](astarte_interfaces.html#io-edgehog-devicemanager-otaevent-v0-1)
and
[`io.edgehog.devicemanager.BaseImage`](astarte_interfaces.html#io-edgehog-devicemanager-baseimage-v0-1)
interfaces.

OTA Update concepts are detailed in the [dedicated page](ota_update_concepts.html), this guide
demonstrates the usage of an OTA update mechanism.

## Managed OTA Updates

Edgehog provides a mechanism to roll-out OTA updates to devices automatically, based on their [System
Model](core_concepts.html#system-model) and their membership to specific [Groups](core_concepts.html#group).

To push updates towards Devices, an Update Campaign must be created. It's important to note that an Update
Campaign can only send updates for the same Base Image Collection. Special operations, such as
converting a Device from one System Model to another, must always be done with a [Manual OTA
Update](#manual-ota-updates).

Once created, the Update Campaign will start rolling out updates towards the devices, and its
progress can be checked from the Edgehog Dashboard or through Edgehog GraphQL API.

Note that the campaign will "snapshot" the Devices belonging to the Channel when it's
started, and will [target](ota_update_concepts.html#update-target) only those.

Once started, the Update Campaign waits for device to come online, at which point it initiates the OTA Update.
[Roll-out mechanim](update_campaigns.html#roll-out-mechanism) properties can affect this process.
For example, `Max Pending Operations` setting may postpone some OTA Operations.

Before actual push to the Device corresponding [Update Target](ota_update_concepts.html#update-target)
is verified for fulfillment of Base Image and Roll-out mechanism criteria. For example:

- Devices having same Base Image version will be silently marked as successful.
- Devices with Base Images that don't meet [Version Requirement](ota_update_concepts.html#version-requirement)
  of distributed Base Image will be marked as failed, unless the `Force Downgrade` option
  of [Push Roll-out mechanism](update_campaigns.html#roll-out-mechanism) is enabled.

## Manual OTA Updates

As an escape hatch, it's always possible to manually update a [Device](core_concepts.html#device)
from its page on the Edgehog dashboard (or using the Edgehog GraphQL API).

Note that Manual OTA Updates do not perform any check on the [System Model](core_concepts.html#system-model),
so they can effectively be used to change the System Model of a Device. This also means that the user
must exercise particular attention to avoid bricking a Device, if the Device does not implement the necessary
safety checks.

![Manual OTA Update Screenshot](assets/manual_ota_update.png)
