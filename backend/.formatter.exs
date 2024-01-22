# SPDX-FileCopyrightText: 2021-2024 SECO Mind Srl
# SPDX-License-Identifier: CC0-1.0

[
  import_deps: [
    :ash,
    :ash_graphql,
    :ash_json_api,
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
  plugins: [Spark.Formatter],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
