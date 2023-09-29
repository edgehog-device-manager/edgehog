<!---
  Copyright 2021-2023 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# OTA Update concepts

This page will illustrate some of the OTA Update concepts used in Edgehog.

## Base Image

A Base Image is an image created to be run on a Device. The exact content of the Base Image can vary
depending on the use case, but it usually contains the operating system image or the device
firmware. Each Base Image belongs to a [Base Image Collection](#base-image-collection).

Base Images follow semantic versioning, so that the user is able to know when a specific update can
contain breaking changes. Each Base Image must have a unique version number.

## Base Image Collection

A Base Image Collection is a set of Base Images associated with a specific [System
Model](core_concepts.html#system-models) and, implicitly via the System Model, with a specific [Hardware
Type](core_concepts.html#hardware-types). The mapping relation between Base Image Collection and System Models is 1:1,
so a Base Image Collection is associated with a single System Model and viceversa.

A Base Image Collection contains all the Base Images that ran, are running or could be run on a
System Model. Drawing from the bike sharing example, there would be a different Base Image
Collection for, e.g., e-bikes from each specific country to handle the different speed limitations.

The primary purpose of a Base Image Collection is to limit what can be installed to a System Model,
preventing unintended installations, such as electric scooter firmware on an e-bike.

## Version Requirement

A Version Requirement specifies compatibility between versions. It is expressed as a string containing
various criteria and adheres to syntax detailed in
[Elixir's Version.Requirement](https://hexdocs.pm/elixir/Version.html#module-requirements).
For example, when the Version Requirement `>= 2.0.0 and < 3.0.0` is used to define the
`Supported starting versions` of Base Image `foo`, it identifies a subset of Base Images
within the same Base Image Collection that can be updated to the Base Image `foo`.

## Update Channel

An Update Channel represents the subscription of a Device to a specific set of Base Images.

Each Device is always associated with an Update Channel (e.g. `default`, `stable`, `beta`, `devel`,
...). To assign a Device to a specific Update Channel (other than the default one) the device must
belong to a [Group](core_concepts.html#group) and that Group has to be assigned to the Target Groups of the Update
Channel.

The same Base Image can be associated with multiple Update Channels. This guarantees
that once testers in the `beta` Update Channel validate the Base Image, the exact same Base Image
will be used to update devices in the `default` Update Channel.

It's possible to automatically assign an Update Channel to one or more [Groups](core_concepts.html#group).

## Update Campaign

An Update Campaign is the operation that tracks the distribution of a specific Base Image to all
devices belonging to an Update Channel.

Each Update Channel can have only one live campaign at a time for a specific System Model, so
creating a new campaign implicitly replaces the old one if it was still active.

An Update Campaign can define additional constraints about which devices can be updated (e.g.
minimum current version, force downgrade, etc).

## Rollout Mechanism

The Rollout Mechanism determines the details of how an Update Campaign is carried out.

It is responsible of deciding if the update is pushed towards the devices or pulled by users
interacting with them.

It also defines other details like how many devices are updated at a time, how many errors should be
supported before aborting the campaign etc.

There are currently two main Mechanisms available: Push and Optional*. The Push mechanism pushes the
update towards the device unconditionally, while the Optional mechanism waits for a confirmation on
the Device side (usually given by a user) before starting to download the update.

*_The Optional rollout mechanism is planned for a future release_

## OTA Operation

An OTA Operation tracks the progress of an update to a specific Device. It is started when Edgehog
starts pushing the update to the Device and ends either with a success or with an error (possibly
due to a timeout).

## Maintenance Window*

*_This feature is planned for a future release_

Each Device can have an optional Maintenance Window. This is used by Update Campaign to determine
which Devices can be updated at a specific time.

If a Device declares a Maintenance Window, the updates targeting it will start only in the interval
defined by it. Note that there's no guarantee that the update will also terminate inside the
Maintenance Window.
