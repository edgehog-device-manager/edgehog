# Core concepts

This page will illustrate some of the core concepts used in Edgehog.

## Hardware types, Devices and Appliance Models

This section will deal with the difference between three main concepts used throughout Edgehog:
Hardware Types, Devices and Appliances.

To better illustrate this, we will use as example the ACME Inc company, which manages a fleet of
e-bikes and electric scooters. We will illustrate the hierarchy going from the bottom up, showing
how each concept relates to the other ones.

### Hardware Type

An Hardware Type represents the electronic hardware components embedded in an Appliance. As an
example, a possible Hardware Type description could be "ESP32 with a GSM module" or "RaspberryPi 0
with an LTE modem".

Each Hardware Type can have one or more Hardware Type Part Numbers associated with it. This makes
sure that the user is able to map, e.g., a new revision of the PCB to the same Hardware Type, since
different hardware with the same Hardware Type is assumed to be compatible. Usually (but not
necessarily) the Hardware Type Part Number is a code that is written on the PCB.

### Device

A device is an entity connected to Astarte. A Device has a uniquely identified by its Device ID, and
it usually lives inside an Appliance (if it is not on a shelf or in a repair shop).

Note that an Appliance is not tied to a specific device forever: using the bike sharing analogy, a
physical e-bike is the appliance, the device is the board which connects it to Astarte. If the board
breaks, it is possible that the e-bike is sent to a repair shop to replace it with a new one. In
that case, the Appliance would stay the same (since the physical bike is always the same), but it
will be associated with a new Device. Moreover, the old Device could actually be repaired and
assigned to a new Appliance.

### Appliance Models

An Appliance Model constitutes a group of Appliances implementing the same functionality for some
users. Two different appliances can be physically identical and still belong to different Appliance
Models, since they can have different software running on them.

An Appliance Model is associated with a specific Hardware Type, so two Appliances implementing the
same functionality but using different Hardware Types will belong to two different Appliance Models.
This makes it so that the Appliance Model is the fundamental identifier when it comes to software
updates.

An Appliance Model has one or more Appliance Model Part Numbers asociated with it, allowing to track
newer versions of an appliance which do not change its main functionality (e.g. a new e-bike model
using brakes from a different vendor). Usually (but not necessarily) the Appliance Model Part Number
is written on the Appliance itself, or on the box containing it.

Drawing again from our bike sharing example, e-bikes and electric scooters would represent two
different Appliance Models, even if they use the same Hardware Type (e.g. an ESP32 with a GSM
module). It is also possible that the e-bikes are further split into different Appliance Models
depending on the country they are deployed in if, for example, the software has to conform to speed
limitations which are specific for each country.
