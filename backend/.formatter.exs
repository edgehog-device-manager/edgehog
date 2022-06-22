# SPDX-FileCopyrightText: 2021-2022 SECO Mind Srl
# SPDX-License-Identifier: CC0-1.0

[
  import_deps: [:ecto, :phoenix, :absinthe, :skogsra, :nimble_parsec],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
