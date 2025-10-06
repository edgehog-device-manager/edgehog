#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

defmodule Doc.MixProject do
  use Mix.Project

  def project do
    [
      app: :doc,
      version: "0.10.0-alpha.5",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Clea Edgehog",
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
        "OTA Updates": ~r"/ota_updates/",
        Architecture: ~r"/architecture/",
        "Admin Guide": ~r"/admin/",
        "Integrating with Edgehog": ~r"/integrating/",
        Tutorials: ~r"/tutorials/"
      ],
      groups_for_modules: [],
      javascript_config_path: "../versions.js"
    ]
  end

  defp extras do
    [
      "pages/user/intro_user.md",
      "pages/user/core_concepts.md",
      "pages/user/hardware_types.md",
      "pages/user/system_models.md",
      "pages/user/devices.md",
      "pages/user/devices_and_runtime.md",
      "pages/user/attribute_value_sources.md",
      "pages/user/groups.md",
      "pages/user/batch_operations.md",
      "pages/ota_updates/ota_update_concepts.md",
      "pages/ota_updates/base_images.md",
      "pages/ota_updates/base_image_collections.md",
      "pages/ota_updates/update_channels.md",
      "pages/ota_updates/update_campaigns.md",
      "pages/ota_updates/ota_updates.md",
      "pages/tutorials/edgehog_in_5_minutes.md",
      "pages/architecture/overview.md",
      "pages/integrating/interacting_with_edgehog.md",
      "pages/integrating/astarte_interfaces.md",
      "pages/admin/deploying_with_kubernetes.md"
    ]
  end
end
