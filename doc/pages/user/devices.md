# Devices

As mentioned in the [core concepts](core_concepts.html), a Device is an entity connected to Astarte.

In the device list you can see all the Devices that are available.

![Devices Screenshot](assets/devices.png)

For each Device the following information can be displayed:

- Name: a user friendly name
- Device ID: the ID that uniquely identifies the device connecting to Astarte
- Appliance Model: the Appliance Model associated to the Device
- Hardware Type: the Hardware Type associated to the Device's Appliance Model
- Status: Reports the connection status, indicating whether the Device is connected to Astarte
- Last Seen: Reports the time of the last connection activity of the Device

Clicking on a Device's name brings to a page dedicated to that Device to display additional info.

## Adding a Device

Each Device will become visible in Edgehog automatically the first time it connects to Astarte.
Indeed, Astarte informs Edgehog about the Device's presence and activity via Astarte Triggers, which
should be configured to relay the appropriate events.

## Associating a Device to an Appliance Model

Each Device is associated to a specific Appliance, hence a specific Appliance Model. The Appliance
Model is the fundamental identifier when it comes to software updates, since it dictates which
software is supported and what functionalities should be configured.

However, during its lifetime, a Device can be tied to different Appliance Models. Say, for example,
that two different models of e-bikes are sent to maintenance; if they share the same hardware, the
working PCB board of one model could be fitted into the other one.

For this reason, each time a Device connects to Astarte, it can notify Astarte about the Appliance
Model it is plugged into, exposing its Part Number. Astarte then informs Edgehog via Astarte
Triggers, so that Edgehog can associate the Device to the correct Appliance Model by matching the
Device's Part Number with the ones of the Appliance Model.

## Device info

On the page of each Device different sets of data are shown. On top of the basic info already
visible in the device list, additional sections can be displayed here to report operational data
exposed by the device.

The details about how devices publish such data are explained in
[Interacting with Edgehog](interacting_with_edgehog.html).

### Hardware info

This section reports an overview on the general hardware capabilities of the Device.

![Device Hardware Info Screenshot](assets/device_hardware_info.png)

### System status

This section reports an overview on the current system status of the Device.

![Device System Status Screenshot](assets/device_system_status.png)

### Storage Status

This section reports an overview on the capacity and usage of the storage units of the Device.

![Device Storage Screenshot](assets/device_storage.png)

### Battery status

This section reports an overview on the current status of the battery slots of the Device.

![Device Battery Screenshot](assets/device_battery.png)

### Nearby WiFi APs

This section reports the list of nearby Access Points that the Device found while scanning for WiFi
signals.

![Device WiFi APs Screenshot](assets/device_wifi_aps.png)

### Geolocation

This section reports the approximate location of the Device, using Edgehog's geolocation modules to
estimate a set of GPS coordinates.

![Device Geolocation Screenshot](assets/device_geolocation.png)

Depending on the data exposed by the Device, the coordinates can be estimated from:

- nearby WiFi APs that the Device detected recently
- the IP address used by the Device to connect to Astarte

Based on the available data, Edgehog's geolocation modules try to find to best estimate by relying
on the most up-to-date info and using the ones that provide the most accuracy.
