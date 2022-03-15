# SPDX-FileCopyrightText: 2021 SECO Mind Srl
# SPDX-License-Identifier: CC0-1.0

[
  import_deps: [:ecto, :phoenix, :absinthe, :skogsra],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
