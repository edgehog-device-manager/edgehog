<!---
  Copyright 2023 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Update Campaigns

As mentioned in the [OTA Update concepts](ota_update_concepts.html), Update Campaign is the operation
that tracks the distribution of a specific [Base Image](ota_update_concepts.html#base-image) to all devices
belonging to a [Channel](ota_update_concepts.html#channel).

Note that an Update Campaign can only send updates for the same
[Base Image Collection](ota_update_concepts.html#base-image-collection), and special operations
(like converting a Device from a one System Model to another) must always be done with a [Manual OTA Update](ota_updates.html#manual-ota-updates).

The following sections will illustrate all the pages that can be used to list, create and view Update Campaigns.

## Update Campaign List

![Update Campaign List Screenshot](assets/update_campaign_list.png)

In the Update Campaign list you can see the table with all Update Campaigns. Clicking on the name brings
to the [Update Campaign](#update-campaign) page.

Clicking on the "Create Update Campaign" button in the top right brings to
[Create Update Campaign](#create-update-campaign) page.

## Create Update Campaign

![Create Update Campaign Screenshot](assets/update_campaign_create.png)

The Create Update Campaign page allows creating a new Update Campaign.

When creating an Update Campaign, the following information must be provided

- Base Image: the target Base Image for the Update Campaign.
- Channel: the target Channel for the Update Campaign.
- [Roll-out Mechanism](#roll-out-mechanism) properties.

The Update Campaign information can be provided using the form, and pressing the "Create" button saves
the Update Campaign.

Once created, the Update Campaign will start rolling out updates towards the devices, and its
progress can be checked from the Edgehog Dashboard or through Edgehog GraphQL API.

Note that the campaign will "snapshot" the Devices belonging to the Channel when it's
started, and will target only those. If additional Devices are added to the Channel (either
manually or automatically via auto-assignment) _after_ the Update Campaign is created, they won't
receive the Base Image and will require a separate campaign to be started.

Only a single Update Campaign can be started for a given System Model and Channel
combination, so creating a new Update Campaign while another one is already running will implicitly
cancel\* the old one. This means that Devices that didn't yet receive the Base Image of the old Update
Campaign will directly receive the new one, without any intermediate step.

\*_Implicit Cancellation feature is planned for a future release_

### Roll-out mechanism

Here are the currently supported Roll-out Mechanisms and their properties

##### `push`

This Roll-out mechanism pushes the update towards the device unconditionally. This can be used to
provide automatic updates where the user should not have the choice of refusing the update.

The properties of this Roll-out Mechanism are:

- Max Pending Operations: the maximum number of pending [OTA Operations](ota_update_concepts.html#ota-operation).
  The Update Campaign will have at most this number of OTA Operations that are started
  but not yet finished (either successfully or not).
- Max Failures: the maximum percentage of failures allowed over the number of total targets. If the failures
  exceed this threshold, the Update Campaign terminates with a failure.
- Request Retries: the number of times an update must be retried on a specific Device before considering it
  a failure. Note that the update is retried only if the OTA Request doesn't get acknowledged from the device.
- Request Timeout: the timeout (in seconds) to wait before considering an OTA Request lost (and possibly retry).
- Force Downgrade (optional): when checked forces downgrading a Device which is currently using a later version
  of the Base Image.

##### `optional`\*

\*_The Optional rollout mechanism is planned for a future release_

This Roll-out mechanism just pushes a message towards the Device informing that an update is
available. The update is downloaded to the device only after the user accepts the update. The update
is not required to be pushed immediately, to provide a backpressure mechanism if many users accept
the update at the same time.

## Update Campaign

![Update Campaign Page Screenshot](assets/update_campaign.png)

The Update Campaign page shows the information about a specific Update Campaign and Devices associated
with it in table below.

Clicking on the Base Image Collection, Base Image, Channel or Device name bring to the corresponding page.
