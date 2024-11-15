# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Added Applications tab to Device page ([#662](https://github.com/edgehog-device-manager/edgehog/issues/662))
- Implemented a application management feature, enabling users to view and navigate through applications and their release details ([#704](https://github.com/edgehog-device-manager/edgehog/issues/704))
  - **Applications page**: Displays a list of all existing applications, with navigation to individual Application pages.
  - **Application page**: Shows the details of a selected application, including its name, description and a list of releases, with navigation to individual Release pages.
  - **Release page**: Provides details of a specific release, including a list of containers and configurations, such as image reference, image credentials (label, username), networks, and port bindings.
- Added `ApplicationCreate` page to enable users to create a new application with fields for application name and description.

## [0.9.1] - 2024-10-28
### Fixed
- Allow receiving `trigger_name` key in trigger payload, which is sent by Astarte >= 1.2.0.

## [0.9.0] - 2024-10-25
### Fixed
- Correctly support automatic login attempts on the frontend regardless of existing auth sessions ([#596](https://github.com/edgehog-device-manager/edgehog/pull/596)).
- Fix file upload for creating base images that was failing due to a regression that left out the `version` parameter, needed for uploading the file ([#600](https://github.com/edgehog-device-manager/edgehog/pull/600)).
### Added
- Check wether `URL_HOST` is a valid host and not a url ([#595](https://github.com/edgehog-device-manager/edgehog/issues/595)).

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
- Add support for an instance of [Edgehog Device
  Forwarder](https://github.com/edgehog-device-manager/edgehog_device_forwarder). When configured,
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
