<!---
  Copyright 2025 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Typos and formatting

In CI we check for typos and the formatting of documents with two tools:

## [create-ci/typos](https://github.com/crate-ci/typos)

For more information on how to install `typos` we link you to their [up-to date documentation](https://github.com/crate-ci/typos#install). If you have the `asdf` package manager however, you can just

```sh
asdf plugin add typos
asdf install
```

since this project publishes a `.tool-versions` file containing `typos`.

## [dprint/check](https://github.com/dprint/check)

`dprint` also has its own [up-to date documentation for installing it](https://dprint.dev/install/). However, this package too can be installed trough `asdf`, hence

```sh
asdf plugin add dprint
asdf install
```

should install it.

## Format markdowns, dockerfiles and jsons

From the root of the project, just run

```sh
dprint fmt
```

`dprint` is already configured to look into the correct files and folders trough the `dprint.json` file.

## Check typos

To check typos, run from the root of the project

```sh
typos
```

The tool will highlight the typos you made, if there's nothing... good! The configuration of this tool is available in our `.typos.toml` file.

## Avoid nitpicking

We made a useful task to avoid nitpicking

```sh
just avoid-nitpick
```

Remember: this checks and corrects words based on the dictionary, it does not check the grammar 😔.
