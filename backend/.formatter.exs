# SPDX-FileCopyrightText: 2021-2023 SECO Mind Srl
# SPDX-License-Identifier: CC0-1.0

[
  import_deps: [
    :ash,
    :ash_graphql,
    :ash_postgres,
    :ecto,
    :phoenix,
    :absinthe,
    :skogsra,
    :nimble_parsec,
    :i18n_helpers,
    :polymorphic_embed,
    :typedstruct
  ],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
