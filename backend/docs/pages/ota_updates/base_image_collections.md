<!---
  Copyright 2023 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Base Image Collections

As mentioned in the [OTA Update concepts](ota_update_concepts.html), Base Image Collection represent
a set of Base Images associated with a specific [System Model](core_concepts.html#system-model) and,
implicitly via the System Model, with a specific [Hardware Type](core_concepts.html#hardware-types).
The mapping relation between Base Image Collection and System Models is 1:1, so a Base Image Collection
is associated with a single System Model and viceversa.

A Base Image Collection contains all the Base Images that ran, are running or could be run on a
System Model. Drawing from the bike sharing example, there would be a different Base Image
Collection for, e.g., e-bikes from each specific country to handle the different speed limitations.

The primary purpose of a Base Image Collection is to limit what can be installed to a System Model,
preventing unintended installations, such as electric scooter firmware on an e-bike.

In Edgehog a Base Image Collection has this information associated with it:

- Name: a user friendly name used to identify the Base Image Collection (e.g. "E-Scooter OS")
- Handle: a machine friendly identifier for the Base Image Collection (e.g. "e-scooter-os"). A valid handle
  must begin with a lowercase letter followed by any number of lower case letters, numbers or dashes (`-`).
- System Model: the System Model that is associated with this Base Image Collection.
- Base Images: a set of Base Images associated with this Base Image Collection.

The following sections will illustrate all the pages that can be used to list, create, edit and delete
Base Image Collections.

## Base Image Collection List

![Base Image Collection List Screenshot](assets/base_image_collection_list.png)

In the base image collection list you can see the table with all Base Image Collections that are available.
Clicking on the name brings to the [Base Image Collection](#base-image-collection) page.

Clicking on the "Create Base Image Collection" button in the top right brings to
[Create Base Image Collection](#create-base-image-collection) page.

## Base Image Collection

![Base Image Collection Page Screenshot](assets/base_image_collection.png)

The Base Image Collection page shows the information about a specific Base Image Collection and Base Images
associated with it in table below.

Editing any field and then pressing the "Update" button saves the new values for the Base Image Collection.
The "Create Base Image" button allows adding additional Base Images to the Base Image Collection.
Clicking on the Base Image Version brings to the Base Image page.
The "Delete" button allows to delete the Base Image Collection.

## Create Base Image Collection

![Create Base Image Collection Screenshot](assets/base_image_collection_create.png)

The Create Base Image Collection page allows creating a new Base Image Collection.

The Base Image Collection information can be provided using the form, and pressing the "Create" button saves
the Base Image Collection. The System Model must be chosen from a list of available System Models using the
dropdown menu.
