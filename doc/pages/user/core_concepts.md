<!---
  Copyright 2021-2023 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

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

## Tags, attributes and groups

This section will deal with various types of properties that can be added to devices to identify
and group them.

### Tags

Tags are string values that can be freely attached to Devices. There is no predefined semantics so
users are free to use them as they see fit.

Some examples of tags that can be assigned to the e-bikes or electric scooters in our examples
could be `out-of-order`, `test_machine` or `Upgraded Brakes`.

### Attributes*

*_This feature is planned for a future release_

Attributes are namespaced key-value pairs that can be attached to Devices. The namespacing happens
by prepending the namespace to the key using a colon as separator (i.e. `namespace:key`). This
ensures that the same key in different namespaces can be addressed unambiguously.

The attribute keys are always strings, while values support all the types [supported by Astarte
Interfaces](https://docs.astarte-platform.org/latest/030-interface.html#supported-data-types).

The majority of attributes are automatically populated using different mechanisms depending on the
namespaces, but there's also the possibility of manually defining custom attributes for a specific
device.

The supported namespaces are:

- `edgehog-synthetic`: automatically populated with values coming from Device data that is derived
  from Edgehog (e.g. Geolocation, System Model, Hardware Type, etc...)
- `edgehog-policy`: automatically populated with Edgehog values which are imposed on the cloud side
  (e.g. Geolocation disabled due to GDPR restrictions).
- `astarte-values`: automatically populated with values coming from device-owned Astarte interfaces
  using an [Attribute Value Source](#attribute-value-source) with type `astarte-value`.
- `astarte-attributes`: automatically populated using the `attributes` map in the Device status
  returned from Astarte AppEngine API. Since Astarte attributes don't provide a trigger mechanism,
  these attributes are lazily populated and should be considered eventually consistent.
- `custom`: user-defined key-value pairs which are manually assigned to a Device.

Note that all values will be converted to a string when using them as attribute values

### Attribute Value Source*

*_This feature is planned for a future release_

An Attribute Value Source populates the attributes of a Device according to some rule.

Currently, the only supported type of Attribute Value Source is `astarte-value`, which updates
Device attributes using a value from an Astarte interface.

### Selector

A Selector allows selecting a subset of Devices based on their tags and attributes. The Selector
can be evaluated for a Device and return `true` if the Device matches the Selector and `false`
otherwise.

Each Selector can be made of one or more filters, combined using `and` and `or` and (possibly)
parenthesized. When no parenthesis are present, `and` has a higher priority than `or` in
expressions.

#### Supported filters

##### Tag filter

Created with the syntax `"<value>" in tags`, it returns `true` if `value` is included in the Device
tags. It's also possible to use a negative filter with `"value" not in tags`, in this case the
filter will match all Devices which _don't_ have the tag.

##### Attribute filter*

*_Note that while Attribute filters are already supported, Attributes are going to be available in a
future release_

Created with the syntax `attributes["<namespace>:<key>"] <operator> <value>`, it returns `true` if
the value of the chosen attribute satisfies the expression.

The supported operators are:
- `==` and `!=` for all value types
- `>`, `>=`, `<`, `<=` for numeric or `datetime` values

`<value>` can be a boolean (`true` or `false`), a string, a number (either integer or float), or one
of the values supported using special syntax:

- `now()` indicates the current datetime at the time the Selector is evaluated. This can be used to
  do comparisons with other `datetime` attributes.
- `datetime("<ISO8601 string>")` is used to pass `datetime` values in expressions. The string
  contained in double quotes must be a valid UTC ISO8601 timestamp. Example:
  `datetime("2022-06-27T16:27:40.254795Z")`.
- `binaryblob("<base64 encoded value>")` is used to pass `binaryblob` values in expressions. The
  string contained in double quotes must be a valid Base64 encoding of the binary value. Example:
  `binaryblob("Zm9vYmFy")` to encode the string `"foobar"`.

##### Attribute inclusion filter*

*_This feature is planned for a future release_

- `"<value>" in attributes["<namespace>:<key>"]`: returns `true` if `value` is included in the
  chosen attribute. Note that the attribute must be an array for the expression to be valid.
  
#### Examples
  
To provide some examples, here is a Selector to target all out of order Devices in Milan:

```
"out-of-order" in tags and attributes["edgehog-synthetic:city"] == "Milan"
```

Here is a selector to target all Devices that have their service timestamp in the past so they have
to be serviced, imagining this information is contained in the `com.foo.ServiceInfo` Astarte
interface in the `/serviceTimestamp`:

```
attributes["astarte-values:com.foo.ServiceInfo/serviceTimestamp"] <= now()
```

#### Caveats

Note that numeric values are conflated in a single numeric type, i.e. a selector with
`attributes["custom:foo"] == 42` will match either if `foo` is `integer`, `longinteger` or `double`
(e.g it will also match `42.0`).

Another important thing to notice is that using an Attribute Filter will implicitly match only
Devices that have that attribute. As an example, if there are 3 devices, one with attribute `foo:bar
== 42`, the other with attribute `foo:bar == 3` and the third one with no `foo:bar` attribute, the
Attribute Filter `attributes["foo:bar"] != 42` will match the second Device but _not_ the third one,
since it doesn't have the target attribute.

In the future, additional syntax could be added to Selectors to allow filtering based just on the
presence or absence of an attribute.

### Group

A Group represents a subset of devices filtered by a Selector.

The Group can be used to perform operations on Devices contained in it (e.g. an [Update
Campaign](#update-campaign)).

Since Tags and Attributes of a Device can change, Groups do not statically define the set of Devices
they contain but they change dynamically following Device changes.

Note that a Device can't be manually assigned to a Group, its tags and attributes must be
used to make it satisfy the group Selector.

## OTA Update Concepts

This section will deal with the concepts used by Edgehog's OTA update mechanism, and it covers
various aspects of the software running on Devices. The [OTA Updates](ota_updates.html) page adds
operative details to the concepts presented here.

### Base Image

A Base Image is an image created to be run on a Device. The exact content of the Base Image can vary
depending on the use case, but it usually contains the operating system image or the device
firmware. Each Base Image belongs to a [Base Image Collection](#base-image-collection).

Base Images follow semantic versioning, so that the user is able to know when a specific update can
contain breaking changes. Each Base Image must have a unique version number.

### Base Image Collection

A Base Image Collection is a set of Base Images associated with a specific [System
Model](#system-models) and, implicitly via the System Model, with a specific [Hardware
Type](#hardware-types). The mapping relation between Base Image Collection and System Models is 1:1,
so a Base Image Collection is associated with a single System Model and viceversa.

A Base Image Collection contains all the Base Images that ran, are running or could be run on a
System Model. Drawing from the bike sharing example, there would be a different Base Image
Collection for, e.g., e-bikes from each specific country to handle the different speed limitations.

The primary purpose of a Base Image Collection is to limit what can be installed to a System Model,
preventing unintended installations, such as electric scooter firmware on an e-bike.

### Version Requirement

A Version Requirement specifies compatibility between versions. It is expressed as a string containing
various criteria and adheres to syntax detailed in
[Elixir's Version.Requirement](https://hexdocs.pm/elixir/Version.html#module-requirements).
For example, when the Version Requirement `>= 2.0.0 and < 3.0.0` is used to define the
`Supported starting versions` of Base Image `foo`, it identifies a subset of Base Images
within the same Base Image Collection that can be updated to the Base Image `foo`.

### Update Channels

An Update Channel represents the subscription of a Device to a specific set of Base Images.

Each Device is always associated with an Update Channel (e.g. `default`, `stable`, `beta`, `devel`,
...). To assign a Device to a specific Update Channel (other than the default one) the device must
belong to a [Group](#group) and that Group has to be assigned to the Target Groups of the Update
Channel.

The same Base Image can be associated with multiple Update Channels. This guarantees
that once testers in the `beta` Update Channel validate the Base Image, the exact same Base Image
will be used to update devices in the `default` Update Channel.

It's possible to automatically assign an Update Channel to one or more [Groups](#group).

### Update Campaign

An Update Campaign is the operation that tracks the distribution of a specific Base Image to all
devices belonging to an Update Channel.

Each Update Channel can have only one live campaign at a time for a specific System Model, so
creating a new campaign implicitly replaces the old one if it was still active.

An Update Campaign can define additional constraints about which devices can be updated (e.g.
minimum current version, allow downgrade, etc).

### Rollout Mechanism

The Rollout Mechanism determines the details of how an Update Campaign is carried out.

It is responsible of deciding if the update is pushed towards the devices or pulled by users
interacting with them.

It also defines other details like how many devices are updated at a time, how many errors should be
supported before aborting the campaign etc.

There are currently two main Mechanisms available: Push and Optional*. The Push mechanism pushes the
update towards the device unconditionally, while the Optional mechanism waits for a confirmation on
the Device side (usually given by a user) before starting to download the update.

*_The Optional rollout mechanism is planned for a future release_

### OTA Operation

An OTA Operation tracks the progress of an update to a specific Device. It is started when Edgehog
starts pushing the update to the Device and ends either with a success or with an error (possibly
due to a timeout).

### Maintenance Window*

*_This feature is planned for a future release_

Each Device can have an optional Maintenance Window. This is used by Update Campaign to determine
which Devices can be updated at a specific time.

If a Device declares a Maintenance Window, the updates targeting it will start only in the interval
defined by it. Note that there's no guarantee that the update will also terminate inside the
Maintenance Window.
