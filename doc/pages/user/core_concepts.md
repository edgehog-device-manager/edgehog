# Core concepts

This page will illustrate some of the core concepts used in Edgehog.

## Hardware types, Devices and System Models

This section will deal with the difference between three main concepts used throughout Edgehog:
Hardware Types, Devices and System Models.

To better illustrate this, we will use as example the ACME Inc company, which manages a fleet of
e-bikes and electric scooters. We will illustrate the hierarchy going from the bottom up, showing
how each concept relates to the other ones.

### Hardware Type

An Hardware Type represents the electronic hardware components embedded in an device. As an example,
a possible Hardware Type description could be "ESP32 with a GSM module" or "RaspberryPi 0 with an
LTE modem".

Each Hardware Type can have one or more Hardware Type Part Numbers associated with it. This makes
sure that the user is able to map, e.g., a new revision of the PCB to the same Hardware Type, since
different hardware with the same Hardware Type is assumed to be compatible. Usually (but not
necessarily) the Hardware Type Part Number is a code that is written on the PCB.

### Device

A device is an entity connected to Astarte. A Device has a uniquely identified by its Device ID, and
it usually lives inside a product such as an e-bike (if it is not on a shelf or in a repair shop).

### System Models

A System Model constitutes a group of devices implementing the same functionality for some users.
For example, two e-bikes can be physically identical and still belong to different System Models,
since they can have different software running on them.

A System Model is associated with a specific Hardware Type, so two devices implementing the same
functionality but using different Hardware Types will belong to two different System Models. This
makes it so that the System Model is the fundamental identifier when it comes to software updates.

A System Model has one or more System Model Part Numbers asociated with it, allowing to track newer
versions of a product which do not change its main functionality. Usually (but not necessarily) the
System Model's Part Number is delivered along with the device, or on the box containing it.

Drawing again from our bike sharing example, e-bikes and electric scooters would have two different
System Models, even if they use the same Hardware Type (e.g. an ESP32 with a GSM module). It is also
possible that the e-bikes are further split into different System Models depending on the country
they are deployed in if, for example, the software has to conform to speed limitations which are
specific for each country.
