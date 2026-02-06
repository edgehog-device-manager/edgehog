<!---
  Copyright 2022 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Groups

Edgehog allows creating groups of Devices based on tags and attributes. This makes it easy to target
them with fleet operations.

All the concepts used below are detailed in the [Core Concepts](core_concepts.html#tags-attributes-and-groups) page, this guide is oriented towards
operational details to create a group.

## Creating a group

A new group can be created from the Groups section of Edgehog.

When creating a group, the following information must be provided:

- Name: the display name of the group
- Handle: an handle matching the `^[a-z][a-z\d\-]*$` regular expression.
- Selector: a [Selector](core_concepts.html#selector) that will determine which Devices belong to
  this group (i.e. all Devices that match the Selector)

## Deleting a group

To delete a group, just press the Delete icon next to it in the group list.

Note that deleting a group means that all automatic operations based on that group (e.g. Channel auto-assignment) will cease to work.
