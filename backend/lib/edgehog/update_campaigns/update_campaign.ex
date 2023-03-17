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
  import PolymorphicEmbed

  alias Edgehog.BaseImages
  alias Edgehog.UpdateCampaigns.PushRollout
  alias Edgehog.UpdateCampaigns.UpdateChannel

  schema "update_campaigns" do
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    field :name, :string
    field :status, Ecto.Enum, values: [:in_progress, :finished]
    field :outcome, Ecto.Enum, values: [:success, :failure]
    belongs_to :base_image, BaseImages.BaseImage
    belongs_to :update_channel, UpdateChannel

    polymorphic_embeds_one :rollout_mechanism,
      types: [push: PushRollout],
      type_field: :type,
      on_replace: :update

    timestamps()
  end

  @doc false
  def changeset(update_campaign, attrs) do
    update_campaign
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> cast_polymorphic_embed(:rollout_mechanism, required: true)
  end
end
