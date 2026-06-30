# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- NOTICE -->
<!-- Starting from v0.11 changelogs are separated per-project. The changes below
refer to both the frontend *and* the backend of edgehog -->

## [0.13.0-rc.1](https://github.com/edgehog-device-manager/edgehog/compare/v0.13.0-rc.0...v0.13.0-rc.1) (2026-06-26)

### Features

* **backend:** add edit and delete to scheduled campaigns ([c41955c](https://github.com/edgehog-device-manager/edgehog/commit/c41955cb9bd88344455ca3410e10393befe7a716))
* **backend:** expand edit for scheduled campaigns ([67bb391](https://github.com/edgehog-device-manager/edgehog/commit/67bb39104168e36babcb5ce8e994c9fde434e643))

### Bug Fixes

* deployment state not updating ([55b1270](https://github.com/edgehog-device-manager/edgehog/commit/55b1270f46714c8da851909bc055e939bb06d95c))
* log only once on deployment events ([6d85ea6](https://github.com/edgehog-device-manager/edgehog/commit/6d85ea655908a0e011b1c714ab3f5dce213ba0c3))

## [0.13.0-rc.0](https://github.com/edgehog-device-manager/edgehog/compare/v0.12.0...v0.13.0-rc.0) (2026-06-15)


### ⚠ BREAKING CHANGES

* direct container creation
* **backend:** - OPENFGA_AUTH_MODEL_ID -renamed_to-> EDGEHOG_OPENFGA_AUTH_MODEL_ID
* **backend:** rename CHECK_ORIGIN_ALLOWED_ORIGINS to GQL_SUBSCRIPTIONS_ALLOWED_ORIGINS
* **backend:** the backend now reads a new environment variable: `CHECK_ORIGIN_ALLOWED_ORIGINS` that sets the allowed origins for graphql subscriptions. If not set the subscriptions will not work in a Kubernetes environment. Please update your environment accordingly

### Features

* add context with deployment requests ([9633598](https://github.com/edgehog-device-manager/edgehog/commit/96335981c794ceb44483de317b51ef2ffae59a9d))
* Add download functionality to uploaded files ([749490a](https://github.com/edgehog-device-manager/edgehog/commit/749490a7cf47c90e3ac23caa6e6edf9efe5d2332))
* add endpoint to check app version ([4a45be6](https://github.com/edgehog-device-manager/edgehog/commit/4a45be686be636a004fb6fc38c6c4718a4a0d0d0))
* Add file delete UI and refine upload naming ([#1406](https://github.com/edgehog-device-manager/edgehog/issues/1406)) ([ffc914a](https://github.com/edgehog-device-manager/edgehog/commit/ffc914a123cf87edefc6d21aa2473c5bc506d3a2))
* Add file download request subscription ([#1313](https://github.com/edgehog-device-manager/edgehog/issues/1313)) ([d097005](https://github.com/edgehog-device-manager/edgehog/commit/d097005bab9dcffe927c90d5cf6ccbd971171efd))
* Add Files Upload tab with manual file download request ([#1270](https://github.com/edgehog-device-manager/edgehog/issues/1270)) ([23f8951](https://github.com/edgehog-device-manager/edgehog/commit/23f895108d890b2f04fdd1db0f76e0724dacfe73))
* add support for container dependencies ([#1463](https://github.com/edgehog-device-manager/edgehog/issues/1463)) ([94553ee](https://github.com/edgehog-device-manager/edgehog/commit/94553ee63abe2f5e9eef60df4f59791a3ba0304c))
* add system-wide debug logging ([3d28525](https://github.com/edgehog-device-manager/edgehog/commit/3d2852515abccff77adb4691fb450860a08f9e51))
* add unified file management with upload and download requests ([7e59bd7](https://github.com/edgehog-device-manager/edgehog/commit/7e59bd7ace150de3fced21491bf0763f5f8367e2))
* Add unique file name constraint and custom file naming support ([2f2a8c9](https://github.com/edgehog-device-manager/edgehog/commit/2f2a8c981f9e1ae33267f4c35fcb434ecb1aceca))
* **backend:** Add CORS policy for GraphQL subscriptions ([#1272](https://github.com/edgehog-device-manager/edgehog/issues/1272)) ([3d77c0a](https://github.com/edgehog-device-manager/edgehog/commit/3d77c0a368c94e7ca5504a8947268327c5de2d6f))
* **backend:** add file download campaigns ([939a63a](https://github.com/edgehog-device-manager/edgehog/commit/939a63aa4f352603f4ceaae8a8aff74fde42aa3c))
* **backend:** Add scheduled campaigns support ([92f295a](https://github.com/edgehog-device-manager/edgehog/commit/92f295a546d304a2f8f18666d350fcdb0e1e7d43))
* **backend:** Add single file download request feature ([799479c](https://github.com/edgehog-device-manager/edgehog/commit/799479c474b3b67a9cf7eb3e62879d282ed3a0ab))
* **backend:** allow devs to setup database connection ([649829a](https://github.com/edgehog-device-manager/edgehog/commit/649829af09106f283e6b929abec2987fbc7cd8fa))
* **backend:** init OpenFGA provider ([2b5096f](https://github.com/edgehog-device-manager/edgehog/commit/2b5096f0ea7bf879fb117671bff50d210d7863c8))
* **backend:** introduce basic FGA model ([471197e](https://github.com/edgehog-device-manager/edgehog/commit/471197e74b751066436f017a87da403fcbb56400))
* **backend:** introduce OpenID Connect fields to `Actor` ([20344f4](https://github.com/edgehog-device-manager/edgehog/commit/20344f470fc39109b1a5f5fd141b139cec1f241e))
* direct container creation ([0a3b465](https://github.com/edgehog-device-manager/edgehog/commit/0a3b46597996c6871fc6ce828e11f90b4a8b4397))
* expose associated FileDownloadCampaign from FileDownloadRequests ([ec8a843](https://github.com/edgehog-device-manager/edgehog/commit/ec8a843a0c56b110cddd30e4ed3b98f202e87f62))
* **frontend:** Add realtime subscriptions for deployment pages ([f4e8fde](https://github.com/edgehog-device-manager/edgehog/commit/f4e8fde5f566bf90fcee0ab6e4ab3f0a5f27c0d3))
* implement file delete request flow ([edd6bfd](https://github.com/edgehog-device-manager/edgehog/commit/edd6bfdcd8674d6e52354f140ef55bfb72c4f52f))
* Implement flow for device files ([45248ce](https://github.com/edgehog-device-manager/edgehog/commit/45248ce85199fe28bfd50dbe8369005311deecea))
* reconcile on retry ([aee844d](https://github.com/edgehog-device-manager/edgehog/commit/aee844d476782bd5bc3b422887c08ed61876d132))


### Bug Fixes

* Add missing trigger for File Delete action ([#1474](https://github.com/edgehog-device-manager/edgehog/issues/1474)) ([e878ad3](https://github.com/edgehog-device-manager/edgehog/commit/e878ad33b1d62ba8678a9bfe82e2f1ed71883da4))
* allow removing devices with deployed volumes ([9c2d233](https://github.com/edgehog-device-manager/edgehog/commit/9c2d2335ed40e8b45e6a2001d5e8ca95a5f80367))
* **backend:** DeploymentEvent interface not working ([eed0dcb](https://github.com/edgehog-device-manager/edgehog/commit/eed0dcbb031653c791577f6bbe9677dcc65191c3))
* **backend:** do not remove containers on release deletion ([#1498](https://github.com/edgehog-device-manager/edgehog/issues/1498)) ([161ae7b](https://github.com/edgehog-device-manager/edgehog/commit/161ae7bc5d79b329d4781086792b53206d38b9e6))
* **backend:** load correct goth env variable ([1aa445e](https://github.com/edgehog-device-manager/edgehog/commit/1aa445e0837135622cfc78996b76d60751e57817))
* **backend:** use correct auth method for presigned urls ([b9f665b](https://github.com/edgehog-device-manager/edgehog/commit/b9f665b1336cc01a4078596a0230aa647f2082a2))
* correct load of realm management client ([d03e737](https://github.com/edgehog-device-manager/edgehog/commit/d03e737bd28a9d2a5af928dda4293bc84aff6df7))
* correct presigned URL filename encoding ([3dda9f4](https://github.com/edgehog-device-manager/edgehog/commit/3dda9f4d6d0a5d8c29011b6ba7020c554256115a))
* do not crash on not loaded device attributes ([7f4f963](https://github.com/edgehog-device-manager/edgehog/commit/7f4f9639b921ea561149d1da383eef3eaad1fbbd))
* do not erase device names ([f7a9e85](https://github.com/edgehog-device-manager/edgehog/commit/f7a9e854bd9a0b5f545649401b2f121a526a00b9))
* Finish scheduled campaigns with no targets ([7d56398](https://github.com/edgehog-device-manager/edgehog/commit/7d56398425936db23ee3d17cf2e3614138a30ca2))
* Fix file upload status setting in the backend ([5aa17ad](https://github.com/edgehog-device-manager/edgehog/commit/5aa17ad029ca8227a43e1f10fa0a915361b39944))
* Generate missing db migration ([cc7f812](https://github.com/edgehog-device-manager/edgehog/commit/cc7f8129526425a59e1e62b2b500b1e488cc5d48))
* Prevent invalid form states for file download requests ([db24f07](https://github.com/edgehog-device-manager/edgehog/commit/db24f074c0125a35e1d7ddf57b92a10cb55fd4c0))
* propagate handler results and optimize dispatch pipeline ([3bec20b](https://github.com/edgehog-device-manager/edgehog/commit/3bec20ba14a405382687d9044fc30b5c28d6ae30))
* run reconciliation after provisioning is complete ([d9938eb](https://github.com/edgehog-device-manager/edgehog/commit/d9938eb1a15292ba3463a52e35ca984f8f8e82d9))
* S3 presign host parsing for schemeless asset hosts ([39ff3f0](https://github.com/edgehog-device-manager/edgehog/commit/39ff3f05f4383b8b9b1f87c8aaa18067b160c854))
* use device_id in deployment relationship inputs ([#1460](https://github.com/edgehog-device-manager/edgehog/issues/1460)) ([b9a5bc3](https://github.com/edgehog-device-manager/edgehog/commit/b9a5bc3700567b7a881f19c4f27d6d817e2bcfaf))
* use translated storage source IDs for storage uploads ([bef6c0c](https://github.com/edgehog-device-manager/edgehog/commit/bef6c0c394e9417e200860ff21cb4e004bb0b8f9))
* Wrong endpoint type in ServerToDevice for fileSizeBytes ([d43c948](https://github.com/edgehog-device-manager/edgehog/commit/d43c94851a57bec9a870be8a6c0c65729e3b3023))


### Performance Improvements

* **backend:** embed `Edgehog.Actors.Actor` resource ([fad68a6](https://github.com/edgehog-device-manager/edgehog/commit/fad68a6386c84be591f857f06a7be89e47b4a93a))
* **backend:** use built-in `&log/3` function ([d817745](https://github.com/edgehog-device-manager/edgehog/commit/d8177450a4f4b49f6e97140cf33513709f32e731))
* better logging ([391caed](https://github.com/edgehog-device-manager/edgehog/commit/391caed00f97afd48088ef315392f9b513b15ee3))
* make marking actions atomic ([37bd5ad](https://github.com/edgehog-device-manager/edgehog/commit/37bd5ad7ba164a59e654318118b5de97222271ef))


### Miscellaneous Chores

* **backend:** rename CHECK_ORIGIN_ALLOWED_ORIGINS to GQL_SUBSCRIPTIONS_ALLOWED_ORIGINS ([89f43e4](https://github.com/edgehog-device-manager/edgehog/commit/89f43e495b17b510a61a999737657e30f657ec6f))
* **backend:** rename openfga env variables ([ad12b92](https://github.com/edgehog-device-manager/edgehog/commit/ad12b92f36597bba370cccb90ff9810f088cad22))
* release 0.13.0-rc.0 ([5893379](https://github.com/edgehog-device-manager/edgehog/commit/58933797f03073daf7817911a54edb65eacc71e3))

## [0.12.0](https://github.com/edgehog-device-manager/edgehog/compare/v0.11.0...v0.12.0) (2026-02-18)


### ⚠ BREAKING CHANGES

* **backend:** remove authentication bypass configuration

### Features

* Add `Pause` and `Resume` functionality for campaigns ([#1204](https://github.com/edgehog-device-manager/edgehog/issues/1204)) ([35a9aab](https://github.com/edgehog-device-manager/edgehog/commit/35a9aab42a458358bf87a60e37453b26a7ac0228)), closes [#277](https://github.com/edgehog-device-manager/edgehog/issues/277)
* add GraphQL subscriptions for containers ([#1224](https://github.com/edgehog-device-manager/edgehog/issues/1224)) ([6c36e6d](https://github.com/edgehog-device-manager/edgehog/commit/6c36e6d0e632251f64a6ffef4a2a304f658f55ad))
* add GraphQL subscriptions for OTA operations ([#1220](https://github.com/edgehog-device-manager/edgehog/issues/1220)) ([db679ce](https://github.com/edgehog-device-manager/edgehog/commit/db679ceebe687909871ed3fee9e59303b4397aa0))
* Add subscriptions for HT and SMPN ([#1225](https://github.com/edgehog-device-manager/edgehog/issues/1225)) ([7d46654](https://github.com/edgehog-device-manager/edgehog/commit/7d466541e3b77f87d84884332046a677d102b441))
* **backend:** add subscriptions to campaigns domain ([2bda866](https://github.com/edgehog-device-manager/edgehog/commit/2bda8661d064a4eb45ade539058930e1b54ddefb))
* **backend:** allow deletion of BaseImage used in completed campaign ([46f7aa3](https://github.com/edgehog-device-manager/edgehog/commit/46f7aa34f585aabf2a37f4baef10a8ac4a5ea33d)), closes [#598](https://github.com/edgehog-device-manager/edgehog/issues/598)


### Miscellaneous Chores

* **backend:** remove authentication bypass configuration ([fb5585c](https://github.com/edgehog-device-manager/edgehog/commit/fb5585ccddc547a7bb5cb084265788d29472fec4))

## [0.11.0](https://github.com/edgehog-device-manager/edgehog/compare/v0.10.0...v0.11.0) (2026-02-03)


### Features

* add calculation to expose Base Image name ([d3affa5](https://github.com/edgehog-device-manager/edgehog/commit/d3affa57af400440a26bccc6c29b3fb9c3534b23))
* add device group subscription ([#1198](https://github.com/edgehog-device-manager/edgehog/issues/1198)) ([adb91f4](https://github.com/edgehog-device-manager/edgehog/commit/adb91f4e5f7011cdf424b77371ebf4f8858f66d1))
* Additional information on deployment events ([ba27473](https://github.com/edgehog-device-manager/edgehog/commit/ba2747342f3b048a695f81deab856ce943aa39ab))
* **backend:** base_images subscriptions ([bf28b85](https://github.com/edgehog-device-manager/edgehog/commit/bf28b85f909e6cfa1a2d8faf0979a4904073df67))
* **backend:** manual OTA with base image from collection ([1af4b8d](https://github.com/edgehog-device-manager/edgehog/commit/1af4b8d8b9f10ca480a2aacf6073e8c2f2297b1c))
* **backend:** run tenant reconciliation at creation ([f806909](https://github.com/edgehog-device-manager/edgehog/commit/f806909c1159ffd6f9171885f8ccee96f2a6f582))
* GraphQL subscription for device updates in table ([#1118](https://github.com/edgehog-device-manager/edgehog/issues/1118)) ([be6a629](https://github.com/edgehog-device-manager/edgehog/commit/be6a6295f2767cf3ae766984aedbc29833a95a06))
* implement GraphQL subscriptions for device events ([32badc9](https://github.com/edgehog-device-manager/edgehog/commit/32badc94a5705f3003ce66c1837430863a0217e3))
* OTA updates can be canceled ([1daed60](https://github.com/edgehog-device-manager/edgehog/commit/1daed60e4fa6af858208f4b3fe3c3863006168c3)), closes [#266](https://github.com/edgehog-device-manager/edgehog/issues/266)
* show `partNumber` and `serialNumber` in `Device` page if available ([#1123](https://github.com/edgehog-device-manager/edgehog/issues/1123)) ([c2261bb](https://github.com/edgehog-device-manager/edgehog/commit/c2261bb7397c4ca956013d245dc16a537e308267)), closes [#226](https://github.com/edgehog-device-manager/edgehog/issues/226)


### Bug Fixes

* **backend:** log errors instead of crashing ([899f431](https://github.com/edgehog-device-manager/edgehog/commit/899f4315f01e67331057dcd11c4dbf0bee11c734))
* device reconciliation not working ([ba1b025](https://github.com/edgehog-device-manager/edgehog/commit/ba1b02530283f69de9cafa5ce4a19cdb117de285))
* Handle reconciler task replies ([bec0758](https://github.com/edgehog-device-manager/edgehog/commit/bec075870002b9e7c9213e7d9d0eeb2fd763d890))
* include tenant in socket options ([d3c8921](https://github.com/edgehog-device-manager/edgehog/commit/d3c89212ca7c4fb25cab293985da144eac3f9188))
* unify device creation and update subscriptions ([c09e7de](https://github.com/edgehog-device-manager/edgehog/commit/c09e7de8d5570cd15f158ade835e9a332c602597))

## [0.10.0] - 2025-12-09

### Fixed

- Migrations now account for the change in constraints in deployment states.
- Delete campaigns now correctly display the state of targets, without duplicate reports of a success.

## [0.10.0-alpha.9] - 2025-12-03

### Added

- Initial draft of the documentation for the container management system.

### Changed

- Astarte `1.3.0-rc.0` is now the first version allowed for device registration
  and deletion triggers.

### Fixed

- `422` answer when trying to delete a tenant. The API now correctly handles the
  `tenant_id`.

## [0.10.0-alpha.8] - 2025-10-28

### Added

- Support for stop campaigns: a deployment campaign can send a `stop` operation on a target release on all devices in a channel.
- Support for start campaigns: a deployment campaign can send a `start` operation on a target release on all devices in a channel.
- Support for upgrade campaigns: a deployment campaign can `update` a container to a newer version on all devices in a channel.
- Support for delete campaigns: a deployment campaign can send a `delete` message on a target release on all devices in a channel.
- Reconciliation logic: container information gets reconciled with astarte if some messages get lost. The polling system acts on time windows to avoid traffic spikes in astarte.
- Retry mechanism: users can manually retry to send necessary messages to a device to deploy a container.

### Changed

- The deployment state does no longer incorporate events, instead events are available in the `events` field of deployments. Users can access them in a _log_ fashion.
- Removed `last_message` field in deployment.
- With Astarte versions >= 1.3, devices are available in Edgehog upon registration, without waiting for their first connection.

### Fixed

- Type error on network and volume options prevented users from using advanced driver options both on volumes and networks.
- Update messages were sent each time a deployment with some ready actions was stopped. This prevented updated releases from actually being stopped.

## [0.10.0-alpha.7] - 2025-10-28

### Changed

- Added a default image for devices that don’t have an associated system model image, replacing the plain grey placeholder
- Containers now allow to specify binds.
- Frontend validation for port bindings support the full docker specification: [docker documentation](https://docs.docker.com/reference/compose-file/services/#ports).
- Adds garbage collection utilities for container resources

## [0.10.0-alpha.6] - 2025-10-16

### Added

- The backend now allows to define different images with the same reference but different image credentials associated.

### Changed

- CPU Period and CPU Quota get validated on the fronted.
- Updated the postgres version in dev, test still run on all versions.
- Added validation for unique volume targets
- Deployment readiness is now a single field
- Deployments now report in the UI the state of each single container. Showing whether the container is running, exited or encountered some error.
- Key-value structure for container environment variables is enforced on backend level.

### Fixed

- Reconciler wrongful map comparison.
- Properly update relay connections to avoid out-of sync errors.

## [0.10.0-alpha.5] - 2025-10-06

### Changed

- When no device group exist, on the Channel List page prompt the user to create at least one group before creating a Channel ([#972](https://github.com/edgehog-device-manager/edgehog/issues/972)).
- Improved how Network and Volumes options can be displayed and edited in the Applications section ([#963](https://github.com/edgehog-device-manager/edgehog/issues/963)).

### Fixed

- Remove application displayed in the application list after deleting it ([#967](https://github.com/edgehog-device-manager/edgehog/issues/967)).
- On the device page, propose only options compatible with the device when users want to upgrade an app's release ([#970](https://github.com/edgehog-device-manager/edgehog/issues/970)).
- Use uniform and readable labels for displaying Restart Policy values of containers ([#971](https://github.com/edgehog-device-manager/edgehog/issues/971)).
- Add logic to resume app campaigns when Edgehog starts up ([#969](https://github.com/edgehog-device-manager/edgehog/issues/969)).

## [0.10.0-alpha.4] - 2025-09-29

### Fixed

- Correctly use Docker's default `false` value for container's readonly root filesystem option.

## [0.10.0-alpha.3] - 2025-09-26

### Fixed

- Astarte reconciler not correctly comparing trigger delivery policies, thus continuously reinstalling them.

## [0.10.0-alpha.2] - 2025-09-26

### Changed

- Improved the web page to create new app releases, with UI adjustments to help users better understand and operate the page.

### Fixed

- Deletion of existing app deployments, not working due to incorrect handling of database constraints.

## [0.10.0-alpha.1] - 2025-09-25

### Fixed

- Failures in handling device events regarding container deployments.
- Incorrect `cGroupPermissions` option not delivered when deploying containers.

## [0.10.0-alpha.0] - 2025-09-24

### Added

- Managed OTA operations expose the update target that created them in graphql ([#356](https://github.com/edgehog-device-manager/edgehog/issues/356)).
- Expose the associated UpdateCampaign (if any) from an OTA Operation on the Software Updates tab ([#356](https://github.com/edgehog-device-manager/edgehog/issues/356)).
- Support for using Azure Storage as the persistence layer for asset uploads ([#233](https://github.com/edgehog-device-manager/edgehog/issues/233)).
- Ecto SSL configuration is exposed through `DATABASE_*` environment variables (see [.env](./.env))
- Adds support for trigger delivery policies in the tenant reconciler, allowing Edgehog to automatically provision and manage trigger delivery policies on Astarte realms that support them (v1.1.1+).
- Added Applications tab to Device page ([#662](https://github.com/edgehog-device-manager/edgehog/issues/662))
- Implemented a application management feature, enabling users to view and navigate through applications and their release details ([#704](https://github.com/edgehog-device-manager/edgehog/issues/704))
  - **Applications page**: Displays a list of all existing applications, with navigation to individual Application pages.
  - **Application page**: Shows the details of a selected application, including its name, description and a list of releases, with navigation to individual Release pages.
  - **Release page**: Provides details of a specific release, including a list of containers and configurations, such as image reference, image credentials (label, username), networks, and port bindings.
- Added `ApplicationCreate` page to enable users to create a new application with fields for application name and description.
- Added `ReleaseCreate` page to enable users to create a new release for an application with fields for release Version and a list of Containers.
- Add upgrade deployment functionality with version selection ([#703](https://github.com/edgehog-device-manager/edgehog/issues/703))
- **Volumes management feature**:
  - **Volumes page** – lists all existing volumes and allows navigation to individual volume pages.
  - **Volume page** – displays details of a selected volume, including its label, driver, and options.
  - **VolumeCreate page** – enables creating a new volume with fields for label, driver, and options.
- Added delete action for release in the releases table of an application
- Added delete action for application in the applications table
- Implemented networks management feature, enabling users to view and create networks.
  - **Networks page** – lists all existing networks and allows navigation to individual network pages.
  - **Network page** – displays details of a selected network, including its label, driver, internal, enableIpv6, and options.
  - **NetworkCreate page** – enables creating a new network with fields for label, driver, internal, enableIpv6, and options.
- Implemented deployments overview with **Deployments page** - lists all deployments and enables filtering by app, release, device.

### Changed

- BREAKING: GraphQL API that return unbounded lists now use Relay/keyset pagination. Edgehog's dashboard now relies on server-side pagination for queries and filtering, and uses tables with infinite scrolling instead of client-side paginated tables.

## [0.9.3] - 2025-05-22

### Fixed

- Base Image deletion in S3 storage
- Update Campaign executor crashing when handling events because of `device` relationship not loaded ([#828](https://github.com/edgehog-device-manager/edgehog/pull/828)).

## [0.9.2] - 2024-12-09

### Added

- Add pattern matching support to device selector DSL with new `~=` and `!~=` operators

### Changed

- Update the docker-compose configuration to allow both physical and virtual devices
  to connect to Edgehog, provided that the devices and the host are on the same LAN.

## [0.9.1] - 2024-10-28

### Fixed

- Allow receiving `trigger_name` key in trigger payload, which is sent by Astarte >= 1.2.0.

## [0.9.0] - 2024-10-25

### Fixed

- Correctly support automatic login attempts on the frontend regardless of existing auth sessions ([#596](https://github.com/edgehog-device-manager/edgehog/pull/596)).
- Fix file upload for creating base images that was failing due to a regression that left out the `version` parameter, needed for uploading the file ([#600](https://github.com/edgehog-device-manager/edgehog/pull/600)).

### Added

- Check whether `URL_HOST` is a valid host and not a url ([#595](https://github.com/edgehog-device-manager/edgehog/issues/595)).

## [0.9.0-rc.2] - 2024-09-11

### Fixed

- Correctly scope Base Image uploads to their Base Image Collection bucket.
- Show a better error when trying to delete a Base Image or Update Channel connected to an existing
  Update Campaign.

### Added

- Support redirection to a specific page after successful authentication

## [0.9.0-rc.1] - 2024-07-10

### Fixed

- Wrong input params used in GraphQL mutation when creating a base image, leading to a rejected operation ([#574](https://github.com/edgehog-device-manager/edgehog/pull/574)).
- Fix docker-compose local build.
- Fix OTA operation events not being handled, leading to a successful OTA operation while the device was still pending.

## [0.9.0-rc.0] - 2024-07-08

### Added

- Allow generating admin JWT using `gen-edgehog-jwt`.

### Changed

- Change logo and brand images with the latest brand revision.
- BREAKING: The Admin API is now JSON-API compliant, which implies a slightly different format,
  check out the newly added OpenAPI document.
- BREAKING: This release includes some breaking changes in the GraphQL API, make sure to check out
  the GraphQL schema if you were using the APIs directly. Note that we _could_ add more breaking
  changes before the final release.

## [0.8.0] - 2024-03-29

### Changed

- Configure cookie attribute based on protocol.
- Normalize triggers when comparing them for reconciliation to avoid useless reconciliations.

## [0.8.0-rc.1] - 2024-03-22

### Fixed

- Fix query limits on Astarte datastream interfaces, leading to parsing failures on some interfaces.

## [0.8.0-rc.0] - 2024-03-21

### Added

- Add support for an instance of [Edgehog Device Forwarder](https://github.com/edgehog-device-manager/edgehog_device_forwarder). When configured,
  forwarding functionalities are enabled for devices that support forwarding connections to their
  internal services, allowing features such as remote terminal sessions
  ([#447](https://github.com/edgehog-device-manager/edgehog/pull/447)).

## [0.7.1] - 2024-02-01

### Added

- Add Admin API to [create](https://github.com/edgehog-device-manager/edgehog/pull/400) and
  to [delete](https://github.com/edgehog-device-manager/edgehog/pull/416) tenants.
- Add a reconciler that takes care of installing Astarte resources (interfaces and triggers) for a
  tenant ([#403](https://github.com/edgehog-device-manager/edgehog/pull/403)).
- BREAKING: Add mandatory `URL_HOST` env variable. It must point to the host where the Edgehog
  backend is exposed.

### Fixed

- Fix seeds not working when used outside docker.
- Fix seeds's default values not working correctly.

## [0.7.0] - 2023-10-06

### Fixed

- Don't crash the OTA campaign if a misconfigured device doesn't send its base image version.
- Correctly return stats even for OTA campaigns with no targets.
- Handle empty string when translating legacy OTAResponse messages.
- Deduplicate tags in list of existing device tags.

## [0.7.0-alpha.1] - 2023-09-12

### Added

- Expose OTA Campaigns stats.

### Fixed

- Fix DevicesTable component for devices without SystemModel.

### Changed

- Enhance the OTA Campaigns frontend, using the exposed stats.

## [0.7.0-alpha.0] - 2023-07-28

### Added

- Add support for device tags ([#191](https://github.com/edgehog-device-manager/edgehog/pull/191), [#212](https://github.com/edgehog-device-manager/edgehog/pull/212)).
- Add support for device custom attributes
  ([#205](https://github.com/edgehog-device-manager/edgehog/pull/205)).
- Add `MAX_UPLOAD_SIZE_BYTES` env variable to define the maximum dimension for uploads (particularly
  relevant for OTA updates). Defaults to 4 GB.
- Allow creating and managing groups based on selectors.
- Add support for device's `network_interfaces` ([#231](https://github.com/edgehog-device-manager/edgehog/pull/231), [#232](https://github.com/edgehog-device-manager/edgehog/pull/232)).
- Add support for base image collections ([#229](https://github.com/edgehog-device-manager/edgehog/pull/229), [#230](https://github.com/edgehog-device-manager/edgehog/pull/230)).
- Add support for base images ([#240](https://github.com/edgehog-device-manager/edgehog/pull/240), [#244](https://github.com/edgehog-device-manager/edgehog/pull/244)).
- Add support for update channels
  ([#243](https://github.com/edgehog-device-manager/edgehog/pull/243), [#245](https://github.com/edgehog-device-manager/edgehog/pull/245)).
- Add support for
  [`io.edgehog.devicemanager.OTAEvent`](https://github.com/edgehog-device-manager/edgehog-astarte-interfaces/pull/58).
- Add support for
  [`io.edgehog.devicemanager.OTARequest`
  v1.0](https://github.com/edgehog-device-manager/edgehog-astarte-interfaces/pull/57).
- Add OTA Campaigns execution support.

### Changed

- Handle Device part numbers for nonexistent system models.
- BREAKING: The `Description` field in the `SystemModel` object is now a `String` instead of a
  `LocalizedText`.

### Deprecated

- Support for `io.edgehog.devicemanager.OTAResponse` is deprecated and will be removed in future
  releases. Switch to `io.edgehog.devicemanager.OTAEvent` instead.
- Support for `io.edgehog.devicemanager.OTARequest` with major version `0` is deprecated and will be
  removed in future releases. Switch to `io.edgehog.devicemanager.OTARequest` major version `1`
  instead.

## [0.5.2] - 2022-06-22

### Added

- Expose Prometheus metrics and a /health API endpoint.

### Changed

- Start using logfmt as logging format.

### Fixed

- Use the tenant's default locale when managing translated descriptions if the user's locale is not
  available.

## [0.5.1] - 2022-06-01

### Added

- Add `connected` field to wifi scan result and highlight the latest connected network
  ([#193](https://github.com/edgehog-device-manager/edgehog/pull/193)).

### Changed

- Change Geo IP provider from FreeGeoIP to IPBase
  ([#190](https://github.com/edgehog-device-manager/edgehog/pull/190)). This is a breaking change,
  make sure to update the `FREEGEOIP_API_KEY` env to `IPBASE_API_KEY`.

### Fixed

- Add a workaround to correctly parse Astarte datastreams even if AppEngine API shows them with a
  inconsistent format ([#194](https://github.com/edgehog-device-manager/edgehog/pull/194)).

## [0.5.0] - 2022-03-22

### Added

- Initial Edgehog release.
