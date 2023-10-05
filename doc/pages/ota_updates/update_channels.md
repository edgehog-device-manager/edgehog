<!---
  Copyright 2023 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Update Channels

As mentioned in the [OTA Update concepts](ota_update_concepts.html), Update Channel represents the subscription
of a Device to a specific set of Base Images.

To assign a Device to a specific Update Channel the device must belong to a [Group](core_concepts.html#group)
and that Group has to be assigned to the Target Groups of the Update Channel.

The same Base Image can be associated with multiple Update Channels. This guarantees
that once testers in the `beta` Update Channel validate the Base Image, the exact same Base Image
will be used to update devices in the `default` Update Channel.

In Edgehog an Update Channels has this information associated with it:

- Name: a user friendly name used to identify the Update Channel (e.g. "Beta").
- Handle: a machine friendly identifier for the Update Channels (e.g. "beta"). A valid handle
  must begin with a lowercase letter followed by any number of lower case letters, numbers or dashes (`-`).
- Target Groups: a list of [groups](groups.html) containing Devices which will
  automatically get assigned to this Update Channel.

A group can be associated only with a single Update Channel. To change the auto-assignment of a
specific group from an Update Channel to another, the group must be removed from the previous Update
Channel and then added to the new one.

The following sections will illustrate all the pages that can be used to list, create, edit and delete
Update Channels.

## Update Channel List

![Update Channel List Screenshot](assets/update_channel_list.png)

In the Update Channel list you can see the table with all Update Channels that are available.
Clicking on the name brings to the [Update Channel](#update-channel) page.

Clicking on the "Create Update Channel" button in the top right brings to
[Create Update Channel](#create-update-channel) page.

## Update Channel

![Update Channel Page Screenshot](assets/update_channel.png)

The Update Channel page shows and allows updating the information about a specific Update Channel.

Editing any field and then pressing the "Update" button saves the new values for the Update Channel.
The "Delete" button allows to delete the Update Channel.

## Create Update Channel

![Create Update Channel Screenshot](assets/update_channel_create.png)

The Create Update Channel page allows creating a new Update Channel.

The Update Channel information can be provided using the form, and pressing the "Create" button saves
the Update Channel. Target Group(s) must be chosen from a list of available Groups using the dropdown menu.
