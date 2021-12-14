# Architecture overview

This is an overview of Edgehog's architecture.

![Edgehog Architecture](assets/edgehog_architecture.png)

The following sections will detail the interactions between Edgehog and the other components
represented in the architecture diagram.

## User interaction

Edgehog exposes two ways to interact with it: a frontend that can be used by users and a GraphQL
API which can be used by third party applications to programmatically perform all actions that can
be performed in the frontend. As a matter of fact, the frontend itself uses the GraphQL API to
perform its tasks.

## Database interaction

Edgehog uses PostgreSQL to store its data. The database schema supports multiple tenants which are
isolated at the database level. This makes it possible to use a single Edgehog instance with
multiple tenants (e.g. in a SaaS scenario).

## Device interaction (through Astarte)

To interact with the other side of the domain (i.e. devices), Edgehog is built upon
[Astarte](https://github.com/astarte-platform/astarte) and it exchanges data with it using two of
its mechanisms: its [REST API](https://docs.astarte-platform.org/latest/api/index.html) and [Astarte
Triggers](https://docs.astarte-platform.org/latest/060-triggers.html). Each Edgehog tenant is mapped
to an Astarte Realm, and it owns the credentials to interact with all the Realm APIs for that
specific Realm.

### Edgehog Astarte Interfaces

The interaction between Edgehog and Astarte is defined by a [set of
interfaces](https://github.com/edgehog-device-manager/edgehog-astarte-interfaces) that define which
data is sent both from Edgehog to the Devices and from the Devices towards Edgehog. Additionally,
connection and disconnection triggers ar installed in the Astarte Realm, and point to the triggers
endpoint of the Edgehog tenant.

### Astarte AppEngine API

The REST API is called every time Edgehog needs to retrieve data contained in
an Astarte interface or when it needs to send data to the Devices. In the first case, Edgehog issues
a `GET` HTTP request to retrieve the data from AppEngine API, which reads the data from the Astarte
database. When Edgehog needs to send data towards a Device instead, it sends a `POST` HTTP to
AppEngine API, which takes care of delivering data via MQTT to the device.

### Astarte Triggers

Astarte Triggers are used to update the online state of the device. Each time a Device connects or
disconnects from Astarte, Astarte Trigger Engine sends an HTTP `POST` request to the Edgehog
backend, which in turn updates the Device online status in its own database.
