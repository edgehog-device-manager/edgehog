<!---
  Copyright 2021,2022 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# System Models

As already mentioned in the [Core concepts](core_concepts.html), System Model represent a group of
devices providing the same functionalities to users.

In Edgehog a System Model has this information associated with it:

- Name: a user friendly name used to identify the System Model (e.g. "E-Bike v2")
- Handle: a machine friendly identifier for the System Model (e.g. "e-bike-v2"). A valid handle must
  begin with a lowercase letter followed by any number of lower case letters, numbers or dashes
  (`-`).
- Hardware type: the [Hardware Type](core_concepts.html#hardware-type) that is used for this system model. 
  Each System Model is associated with exactly one Hardware Type.
- Part numbers: the Part Numbers for this System Model. Each System Model can have one or more Part
  Numbers associated with it, and Devices will be associated with a System Model based on the Part
  Number they declare to implement.
- Picture: each System Model can have a picture associated with it, so that Devices using that
  System Model can be identified at a glance.

The following sections will illustrate all the pages that can be used to list, create and edit
System Models.

## System Model List

![System Model List Screenshot](assets/system_models.png)

In the system model list you can see all the System Models that are available. All information
relative to each System Model (minus the picture) is present in the table, and clicking on the name
brings to the [System Model](#system-model) page.

Clicking on the "Create System Model" button in the top right brings to
[Create System Model](#create-system-model) page.

## System Model

![System Model Page Screenshot](assets/system_model.png)

The System Model page shows the information about a specific System Model and allows updating all of
them except the Hardware Type.

Editing any field and then pressing the "Update" button saves the new values for the System Model.
The "Add Part Number" button allows adding additional Part Numbers to a System Model, and the thrash
icon on the right of each of them allows deleting them.

## Create System Model

![Create System Model Screenshot](assets/create_system_model.png)

The Create System Model page allows creating a new System Model.

The System Model information can be provided using the form, and pressing the "Update" button saves
the System Model. The Hardware Type must be chosen from a list of available Hardware Types using the
dropdown menu. The "Add Part Number" button allows adding additional Part Numbers for the System
Model.
