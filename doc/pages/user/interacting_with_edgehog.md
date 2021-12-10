# Interacting with Edgehog

Edgehog's interaction is logically divided amongst two main entities: devices and users.

_Devices_ are the bottom end, and represent the IoT fleet. They can access
[Astarte](https://github.com/astarte-platform/astarte) and exchange data via Astarte Interfaces
which, in turn, also define on a very granular level which kind of data they can exchange. Data
exposed by devices are relayed to Edgehog via Astarte Triggers.

_Users_ are actual users, applications or anything else which needs to interact with Edgehog.

## User-side Tools

To interact with Edgehog, several options are available:

- Edgehog's dashboard interface: it provides a built-in UI that can be used for managing Devices,
  Hardware Types, and Appliance Models. It is meant to be a graphical, user-friendly tool to manage
  those entities.
- [Edgehog's GraphQL APIs](graphql-api-docs/): they are meant as a machine-friendly way to perform
  operations on Edgehog's entities and for integrating 3rd party applications.

## Publishing Device data

Devices can publish any kind of data to Astarte via Astarte Interfaces. However, some standard
interfaces are already supported by Edgehog in order to provide useful functionalities, such as
device geolocation.

Hence, data that devices send via
[Edgehog's Astarte Interfaces](https://github.com/edgehog-device-manager/edgehog-astarte-interfaces/)
are automatically understood, collected and reported by Edgehog.

### Publishing info about the Appliance

Each Device is supposed to notify Astarte, e.g. on each connection, about the Appliance Model it is
plugged into.

To do so, the Device can use the `io.edgehog.devicemanager.ApplianceInfo` Astarte Interface to
specify:

- the Serial Number: a code that uniquely identifies the Appliance
- the Part Number: a code that uniquely identifies the Appliance Model

When exposing the Part Number, Edgehog can associate the Device to the correct Appliance Model by
matching the Device's Part Number with the ones of the registered Appliance Model.

### Publishing info about the hardware

Each Device can notify Astarte about the general capabilities of the Device. These info are
hardware-related and are usually not intended to change over time.

A Device can expose this set of data via the `io.edgehog.devicemanager.HardwareInfo` Astarte
Interface.

### Publishing info about the Device status

To expose info about its current status or measured data, some additional Astarte Interfaces are
already defined for Edgehog. Their adoption is optional but recommended.

This section reports an overview on the current system status of the Device.

- `io.edgehog.devicemanager.SystemStatus`: reports the current OS status.
- `io.edgehog.devicemanager.StorageUsage`: reports the capacity and usage of the storage units.
- `io.edgehog.devicemanager.BatteryStatus`: reports the current status of the battery slots.
- `io.edgehog.devicemanager.WiFiScanResults`: reports the list of nearby Access Points that the
  Device found while scanning for WiFi signals.
