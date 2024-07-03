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

defmodule Edgehog.UpdateCampaigns.UpdateChannel.Calculations.UpdatableDevices do
  use Ash.Resource.Calculation

  require Ash.Query

  @impl true
  def calculate(update_channels, _opts, context) do
    %{arguments: %{base_image: base_image}} = context

    base_image = Ash.load!(base_image, base_image_collection: [:system_model_id])

    system_model_id = base_image.base_image_collection.system_model_id

    update_channels
    |> Ash.load!(target_groups: [devices: :system_model])
    |> Enum.map(fn update_channel ->
      update_channel.target_groups
      |> Enum.flat_map(fn target_group ->
        Enum.filter(
          target_group.devices,
          &(&1.system_model != nil && &1.system_model.id == system_model_id)
        )
      end)
      |> Enum.uniq_by(& &1.id)
    end)
  end
end
