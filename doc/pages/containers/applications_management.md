<!---
  Copyright 2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Applications management

## Release creation process

To create a Release in Edgehog:

1. Navigate to the **Applications** section in the Edgehog web interface
2. Open the app for which you want to create a release
3. Click on **Create Release** action button
4. Fill in the release form:
   - **Version**: Enter a unique version number that follows the [Semantic Versioning](https://semver.org) spec
   - **Supported System Models**: Choose system model(s) which the release should support. If left blank, the release supports all devices
5. Add container(s) by clicking **Add Container** button (see [Container creation](applications_management#container-creation) for more details)
6. Click **Create** to create the release

![Creating Release](assets/release_create.png)

### Reuse Release Configuration

Edgehog also let's you reuse existing containers and their configurations from the same or some other application.

To reuse a Release:

1. Click on **Reuse Release** button in the Create Release page
2. Choose application and release from which you want to copy containers and their configurations
3. Click **Confirm** to import release configuration

![Reusing Release](assets/release_create_reuse.png)

### Container creation
