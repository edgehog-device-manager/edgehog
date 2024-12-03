# SPDX-FileCopyrightText: 2021-2024 SECO Mind Srl
# SPDX-License-Identifier: CC0-1.0

[
  import_deps: [
    :ash,
    :ash_graphql,
    :ash_json_api,
    :ash_postgres,
    :ecto,
    :ecto_sql,
    :phoenix,
    :absinthe,
    :skogsra,
    :nimble_parsec
  ],
  plugins: [Spark.Formatter],
  line_length: 120,
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
