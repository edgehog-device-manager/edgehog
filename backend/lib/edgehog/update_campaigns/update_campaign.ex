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

defmodule Edgehog.UpdateCampaigns.UpdateCampaign do
  use Ecto.Schema
  import Ecto.Changeset

  schema "update_campaigns" do
    field :name, :string
    field :rollout_mechanism, :map
    field :tenant_id, :id
    field :base_image_id, :id
    field :update_channel_id, :id
    field :status, Ecto.Enum, values: [:in_progress, :finished]
    field :outcome, Ecto.Enum, values: [:success, :failure]

    timestamps()
  end

  @doc false
  def changeset(update_campaign, attrs) do
    update_campaign
    |> cast(attrs, [:name, :rollout_mechanism])
    |> validate_required([:name, :rollout_mechanism])
  end
end
