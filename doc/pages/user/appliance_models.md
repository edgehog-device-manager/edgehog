# Appliance models

As already mentioned in the [core concepts](core_concepts.html), Appliance Models represent a group
of Appliances providing the same functionalities to users.

In Edgehog an Appliance Model has this information associated with it:

* Name: a user friendly name used to identify the Appliance Model (e.g. "E-Bike v2")
* Handle: a machine friendly identifier for the Appliance Model (e.g. "e-bike-v2"). A valid handle
  must begin with a lowercase letter followed by any number of lower case letters, numbers or dashes
  (`-`).
* Hardware type: the Hardware Type that is used for this appliance model. As illustrated in [core
  concepts](core_concepts.html), each Appliance Model is associated with exactly one Hardware Type.
* Part numbers: the Part Numbers for this Appliance Model. Each Appliance Model can have one or more
  Part Numbers associated with it, and Devices will be associated with an Appliance Model based on
  the Part Number they declare to implement.
* Picture: each Appliance Model can have a picture associated with it, so that Devices using that
  Appliance Model can be identified at a glance.

The following sections will illustrate all the pages that can be used to list, create and edit
Appliance Models.

## Appliance Model List

![Appliance Model List Screenshot](assets/appliance_models.png)

In the appliance model list you can see all the Appliance Models that are available. All information
relative to each Appliance Model (minus the picture) is present in the table, and clicking on the
name brings to the [Appliance Model](#appliance-model) page.

Clicking on the "Create Appliance Model" button in the top right brings to [Create Appliance
Model](#create-appliance-model) page.

## Appliance Model

![Appliance Model Page Screenshot](assets/appliance_model.png)

The Appliance Model page shows the information about a specific Appliance Model and allows updating
all of them except the Hardware Type.

Editing any field and then pressing the "Update" button saves the new values for the Appliance
Model. The "Add Part Number" button allows adding additional Part Numbers to an Appliance Model, and
the thrash icon on the right of each of them allows deleting them.

## Create Appliance Model

![Create Appliance Model Screenshot](assets/create_appliance_model.png)

The Create Appliance Model page allows creating a new Appliance Model.

The Appliance Model information can be provided using the form, and pressing the "Update" button
saves the Appliance Model. The Hardware Type must be chosen from a list of available Hardware Types
using the dropdown menu. The "Add Part Number" button allows adding additional Part Numbers for the
Appliance Model.
