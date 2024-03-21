# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0-dev] - Unreleased

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
