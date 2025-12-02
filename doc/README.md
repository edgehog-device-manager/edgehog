<!---
  Copyright 2021,2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Doc

This module contains Edgehog's documentation.

Documentation is published [at this link](https://docs.edgehog.io/), with the latest
snapshot available [here](https://docs.edgehog.io/snapshot/).

## Contributing

To contribute, you can simply create and edit the sources in the `pages` directory.
Images and other assets are instead in the `assets` directory.

To locally preview your changes, use this command:

```sh
mix docs
```

The output will be inserted in the `doc` directory, and you can visualize it with
any browser.

### Generating a `astarte_interfaces` page

You may notice that the `pages/integrating/astarte_interfaces.md` file is
empty. This is because it is needed for the build task to succeed. However, in
the real documentation this file is actually automatically generated from the
contents of the
[edgehog-astarte-interfaces repo](https://github.com/edgehog-device-manager/edgehog-astarte-interfaces.git).
If you want to recreate this setup, you can simply follow the following
instructions.

> [!IMPORTANT]
> Because of git, any changes to the file are tracked, and could be
> accidentally added in your commit. You can avoid it with
>
> ```sh
> git update-index --assume-unchanged path/to/edgehog/doc/pages/integrating/astarte_interfaces.md
> ```

First of all, clone the [edgehog-astarte-interfaces](https://github.com/edgehog-device-manager/edgehog-astarte-interfaces)
repository:

```sh
git clone https://github.com/edgehog-device-manager/edgehog-astarte-interfaces.git
# or via ssh
git clone git@github.com:edgehog-device-manager/edgehog-astarte-interfaces.git
```

Next, you need to install the [`astarte-docs`](https://www.npmjs.com/package/@astarte-platform/astarte-docs-cli)
tool. To do so, use `npm`:

```sh
npm install -g @astarte-platform/astarte-docs-cli@0.0.7
```

Finally, use it to generate the page:

```sh
astarte-docs interfaces gen-markdown -d path/to/edgehog-astarte-interfaces -o path/to/edgehog/doc/pages/integrating/astarte_interfaces.md
```
