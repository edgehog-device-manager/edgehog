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
      main: "intro_user",
      logo: "images/logo-favicon.png",
      extras: extras(),
      assets: "images/",
      api_reference: false,
      groups_for_extras: [
        "User Guide": ~r"/user/",
        Architecture: ~r"/architecture/"
      ],
      groups_for_modules: []
    ]
  end

  defp extras do
    [
      "pages/user/intro_user.md",
      "pages/user/core_concepts.md",
      "pages/user/hardware_types.md",
      "pages/user/appliance_models.md",
      "pages/user/devices.md",
      "pages/user/interacting_with_edgehog.md",
      "pages/architecture/overview.md"
    ]
  end
end
