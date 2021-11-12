defmodule Doc.MixProject do
  use Mix.Project

  def project do
    [
      app: :doc,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Edgehog",
      homepage_url: "http://edgehog.io",
      docs: docs()
    ]
  end

  defp deps do
    [{:ex_doc, "~> 0.24", only: :dev}]
  end

  # Add here additional documentation files
  defp docs do
    [
      main: "001-intro_user",
      logo: "images/logo-favicon.png",
      extras: Path.wildcard("pages/*/*.md"),
      assets: "images/",
      api_reference: false,
      groups_for_extras: [
        "User Guide": ~r"/user/"
      ],
      groups_for_modules: []
    ]
  end
end
