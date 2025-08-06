#
# This file is part of Edgehog.
#
# Copyright 2023 - 2025 SECO Mind Srl
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

defmodule Edgehog.Tenants.Reconciler.AstarteResources do
  @moduledoc false
  @interfaces Path.wildcard("priv/astarte_resources/interfaces/*.json")
  @delivery_policies Path.wildcard("priv/astarte_resources/delivery_policies/*.json.eex")
  @trigger_templates Path.wildcard("priv/astarte_resources/trigger_templates/*.json.eex")

  # Ensure we recompile code if trigger templates or interfaces change
  for resource <- @interfaces ++ @delivery_policies ++ @trigger_templates do
    @external_resource resource
  end

  def load_interfaces do
    Enum.map(@interfaces, fn interface ->
      interface
      |> File.read!()
      |> Jason.decode!()
    end)
  end

  def load_delivery_policies do
    Enum.map(@delivery_policies, &File.read!/1)
  end

  def load_trigger_templates do
    Enum.map(@trigger_templates, &File.read!/1)
  end
end
