#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Devices.Device.ManualRelationships.SystemModel do
  use Ash.Resource.ManualRelationship

  alias Edgehog.Devices.SystemModel
  require Ash.Query

  @impl Ash.Resource.ManualRelationship
  def load(devices, _opts, %{tenant: tenant}) do
    device_ids = Enum.map(devices, & &1.id)

    related_system_models =
      SystemModel
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.filter(part_numbers.devices.id in ^device_ids)
      |> Ash.Query.load(part_numbers: [:devices])
      |> Ash.read!()

    device_id_to_system_models =
      related_system_models
      |> Enum.flat_map(fn system_model ->
        system_model.part_numbers
        |> Enum.flat_map(fn part_number ->
          Enum.map(part_number.devices, &{&1.id, system_model})
        end)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    {:ok, device_id_to_system_models}
  end
end
