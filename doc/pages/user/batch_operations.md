<!---
  Copyright 2023 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Batch Operations*

*_This feature is planned for a future release_

Edgehog provides facilities to perform batch operations on groups of devices. These are used to
avoid having to perform repetitive tasks on many devices.

This guide presents the batch operations which can be performed using Edgehog.

## Maintenance Window Setting

Using the Edgehog API or its frontend, it is possible to set the same [Maintenance
Window](core_concepts.html#maintenance-window) to all devices belonging to a Group.

When performing the operation, the following information must be provided

- Maintenance Window Start: the UTC timestamp that marks the beginning of the Maintenance Window
- Maintenance Window End: the UTC timestamp that marks the end of the Maintenance Window
- Group: the name of the target group

All devices belonging to the Group when the operation is started will be assigned the new
Maintenance Window. Note that the Maintenance Window remains a property of the single device and the
assignment is performed one-shot when the operation is performed (i.e. Devices that become member of
the group later are not affected by it).
