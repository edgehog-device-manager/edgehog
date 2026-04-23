<!---
  Copyright 2026 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Edgehog

![Backend CI](https://github.com/edgehog-device-manager/edgehog/actions/workflows/backend-ci.yaml/badge.svg)
![Frontend CI](https://github.com/edgehog-device-manager/edgehog/actions/workflows/frontend-ci.yaml/badge.svg)
![Coverage](https://img.shields.io/coverallsCoverage/github/edgehog-device-manager/edgehog)

**License:** Apache 2.0 — [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0.html)

An open-source IoT device fleet management platform built on [Astarte](https://github.com/astarte-platform/astarte). Manage hardware, push firmware updates, track device health, and automate deployments — all through a single GraphQL API.

## What Edgehog does

<div class="feature-cards">
<div class="feature-card">
<div class="card-icon" style="background: #e0f5f0;">📡</div>
<h3>Device management</h3>
<p>Register and monitor your entire device fleet. Query real-time status: online/offline state, last-seen IP, cellular connectivity, battery, OS info, and hardware details.</p>
</div>

<div class="feature-card">
<div class="card-icon" style="background: #fff4e0;">🔄</div>
<h3>OTA update campaigns</h3>
<p>Create base image collections and roll out firmware upgrades across device groups using campaigns.</p>
</div>

<div class="feature-card">
<div class="card-icon" style="background: #e8f0ff;">📦</div>
<h3>Container deployments</h3>
<p>Define applications as versioned releases of containers. Deploy, upgrade, start, stop, and delete containerized workloads via deployment campaigns.</p>
</div>

<div class="feature-card">
<div class="card-icon" style="background: #fce8f0;">📊</div>
<h3>Fleet grouping</h3>
<p>Tag devices freely and write selector expressions to form dynamic groups that update automatically.</p>
</div>

<div class="feature-card">
<div class="card-icon" style="background: #eaf3de;">📍</div>
<h3>Geolocation</h3>
<p>Track device position and location data reported from the field. Query per-device position and last-seen coordinates through the API.</p>
</div>

<div class="feature-card">
<div class="card-icon" style="background: #eeedfe;">🔗</div>
<h3>Remote Forwarding</h3>
<p>Request and manage forwarder sessions to tunnel traffic to specific devices for diagnostics and remote access — configurable per tenant.</p>
</div>
</div>

## API reference

### Admin REST APIs

Edgehog admin tasks (i.e., managing tenants) are available through a REST API. It supports creating, updating and deleting tenants

**Endpoint**

```
http://<your-host>/admin-api/v1/
```

Replace `<your-host>` with your Edgehog instance hostname.

**Full API docs** available here: [admin-rest-api](admin-rest-api/)

### Tenant GraphQL APIs

All Edgehog operations are exposed through a **GraphQL API**. It supports queries, mutations, and real-time subscriptions.

**Endpoint**

```
http://<your-host>/tenants/<your-tenant>/api
```

Replace `<your-host>` with your Edgehog instance hostname and `<your-tenant>` with the slug of your tenant.

**Full API docs** available here: [tenant-graphql-api](tenant-graphql-api/)

#### Key resources

| [**Queries**](https://docs.edgehog.io/0.12/tenant-graphql-api/#group-Operations-Queries) | Query your device data. |
| [**Mutations**](https://docs.edgehog.io/0.12/tenant-graphql-api/#group-Operations-Mutations) | Make changes and interact with Edgehog. |
| [**Subscriptions**](https://docs.edgehog.io/0.12/tenant-graphql-api/#group-Operations-Subscriptions) | Subscribe to events as they happen. |

## How to read this documentation

**1. Core concepts**

Before exploring features or the API, read the [Core concepts](core_concepts-1.html) page. It defines the building blocks (**Hardware Types**, **Devices**, **System Models**, **Groups**, and **Selectors**) that all other sections depend on.

**2. Follow the feature guides**

The sidebar organizes topics from setup (hardware types, system models) to operations (OTA updates, campaigns, container deployments). Work through them sequentially: each guide builds on the vocabulary established by the previous one.

**3. Use the API reference for integration work**

The [GraphQL API reference](https://docs.edgehog.io/0.12/tenant-graphql-api/) lists every query, mutation, and subscription with argument types and example payloads. Use it alongside the feature guides when building integrations or automating fleet operations.

**4. Note features marked as planned**

Sections marked with an asterisk (\*) (such as Attributes and Attribute filters) describe functionality planned for a future release. The selector syntax for attributes is already in place, but attribute population is not yet active. Treat these sections as forward reference only.

**5. Download or explore offline**

An ePub version of the full documentation is available at the bottom of any page. A [llms.txt](llms.txt) is also provided for machine-readable consumption.
