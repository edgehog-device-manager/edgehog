# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.2] - Unreleased
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
  ([#193](https://github.com/edgehog-device-manager/edgehog/pull/193))

### Changed
- Change Geo IP provider from FreeGeoIP to IPBase
  ([#190](https://github.com/edgehog-device-manager/edgehog/pull/190)). This is a breaking change,
  make sure to update the `FREEGEOIP_API_KEY` env to `IPBASE_API_KEY`.

### Fixed
- Add a workaround to correctly parse Astarte datastreams even if AppEngine API shows them with a
  inconsistent format ([#194](https://github.com/edgehog-device-manager/edgehog/pull/194))

## [0.5.0] - 2022-03-22
### Added
- Initial Edgehog release
