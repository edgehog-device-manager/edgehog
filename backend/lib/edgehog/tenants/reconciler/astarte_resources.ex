#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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
  @interfaces Path.wildcard("priv/astarte_resources/interfaces/*.json")
  @trigger_templates Path.wildcard("priv/astarte_resources/trigger_templates/*.json.eex")

  # Ensure we recompile code if trigger templates or interfaces change
  for resource <- @interfaces ++ @trigger_templates do
    @external_resource resource
  end

  def load_interfaces do
    @interfaces
    |> Enum.map(&File.read!/1)
    |> Enum.map(&Jason.decode!/1)
  end

  def load_trigger_templates do
    @trigger_templates
    |> Enum.map(&File.read!/1)
  end
end
