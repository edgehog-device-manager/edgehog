# SPDX-FileCopyrightText: 2021-2026 SECO Mind Srl
# SPDX-License-Identifier: CC0-1.0

[
  import_deps: [
    :oban,
    :ash,
    :ash_graphql,
    :ash_json_api,
    :ash_postgres,
    :ecto,
    :ecto_sql,
    :phoenix,
    :phoenix_live_view,
    :ash_phoenix,
    :cinder,
    :absinthe,
    :skogsra,
    :nimble_parsec
  ],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs,heex}"],
  subdirectories: ["priv/*/migrations"],
  locals_without_parens: [
    assert_created: 3,
    assert_updated: 3,
    triggers: 1,
    trigger: 1,
    handler: 1
  ]
]
