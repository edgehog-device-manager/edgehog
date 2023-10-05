<!---
  Copyright 2023 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Base Images

As mentioned in the [OTA Update concepts](ota_update_concepts.html), Base Image is an image created
to be run on a Device. The exact content of the Base Image can vary depending on the use case,
but it usually contains the operating system image or the device firmware. Each Base Image belongs to
a [Base Image Collection](ota_update_concepts.html#base-image-collection).

Base Images follow semantic versioning, so that the user is able to know when a specific update can
contain breaking changes. Each Base Image must have a unique version number.

In Edgehog a Base Image has this information associated with it:

- Base Image Collection: the Base Image Collection that is associated with this Base Image.
- Base Image URL: link to a file with the Base Image content.
- Version: a version number following the [Semantic Versioning](https://semver.org) spec. The
  version number must be unique.
- Supported starting versions (optional): a [Version Requirement](ota_update_concepts.html#version-requirement)
  that the Device must satisfy with its current Base Image to be updated with this Base Image.
  If a Device that does not satisfy the requirement is included in an Update Campaign
  that uses this Base Image, the result of the [OTA Operation](ota_update_concepts.html#ota-operation) is an error.
- Release Display Name (optional): a localized user-friendly name for the release.
- Description (optional): a localized description of the content of the Base Image.

The following sections will illustrate all the pages that can be used to list, create, edit and delete
Base Images.

## Base Image List

![Base Image List Screenshot](assets/base_image_list.png)

The Base Image Collection page shows table with associated Base Images.
Clicking on the Base Image Version brings to the [Base Image](#base-image) page.
Clicking on the "Create Base Image" button in the right brings to the [Create Base Image](#create-base-image) page.

## Base Image

![Base Image Page Screenshot](assets/base_image.png)

The Base Image page shows the information about a specific Base Image and allows updating some of them.

Editing any field and then pressing the "Update" button saves the new values for the Base Image.
The "Delete" button allows to delete the Base Image.

## Create Base Image

![Create Base Image Screenshot](assets/base_image_create.png)

The Create Base Image page allows creating a new Base Image.

The Base Image information can be provided using the form, and pressing the "Create" button saves the Base Image.

Some information can be automatically filled in if the Base Image can be parsed by one of the
[supported Base Image parsers](#supported-base-image-parsers). Other than that, users are free to
use whatever format they choose for the artifact that will be pushed towards the device, provided
the Device is able to handle it.

When you upload add Base Image in a Base Image Collection, no update is pushed towards devices,
the Base Image is just uploaded in Edgehog's storage. To start pushing updates towards devices, an
[Update Campaign](ota_update_concepts.html#update-campaign) must be created.

### Supported Base Image parsers

Base Image parsers are not implemented yet. As soon as they are implemented, this section will be
populated with the supported formats.