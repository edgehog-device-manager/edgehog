<!---
  Copyright 2022 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Attribute Value Sources

Device attributes can be populated using external sources using Attribute Value Sources. These
provide mechanisms to automatically update some device attributes according to some rules.

All the concepts used below are detailed in the [Core Concepts](core_concepts.html#tags-attributes-and-groups) page, this guide is oriented towards
operational details to use Attribute Value Sources.

## Populating attributes using Astarte values

To populate an attribute using a value coming from an Astarte interface, an Attribute Value Source
of type `astarte-value` must be added. This will populate an attribute whose value will be
eventually consistent with the value of the target Astarte interface and path.

When creating an `astarte-value` Attribute Value Source, the following information must be provided:

- Interface: the target interface to be used
- Major version: the target major version of the interface
- Path: the target path containing the value that will be used as attribute value

After its creation, the Attribute Value Source will install an Astarte trigger, so when the target
interface value changes, the change will be (eventually) reflected in the Attribute value. The
Attribute key will be `astarte-value:<interface-name><path>`. The value will also be initialized
asynchronously for all devices by querying AppEngine API in a background task.
