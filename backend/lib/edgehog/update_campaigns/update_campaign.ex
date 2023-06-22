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
  alias Edgehog.UpdateCampaigns.Target

  @rollout_mechanism_types [push: PushRollout]

  schema "update_campaigns" do
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    field :name, :string
    field :status, Ecto.Enum, values: [:idle, :in_progress, :finished]
    field :outcome, Ecto.Enum, values: [:success, :failure]
    field :start_timestamp, :utc_datetime_usec
    field :completion_timestamp, :utc_datetime_usec
    belongs_to :base_image, BaseImages.BaseImage
    belongs_to :update_channel, UpdateChannel

    polymorphic_embeds_one :rollout_mechanism,
      types: @rollout_mechanism_types,
      type_field: :type,
      on_replace: :update

    has_many :update_targets, Target

    timestamps()
  end

  @doc false
  def create_changeset(update_campaign, attrs) do
    do_changeset(update_campaign, attrs, rollout_mechanism_changeset_function: :create_changeset)
  end

  @doc false
  def changeset(update_campaign, attrs) do
    prev_rollout_mechanism_type = update_campaign.rollout_mechanism

    do_changeset(update_campaign, attrs)
    |> validate_change(
      :rollout_mechanism,
      &preserve_rollout_mechanism_type(&1, prev_rollout_mechanism_type, &2)
    )
  end

  defp do_changeset(update_campaign, attrs, opts \\ []) do
    rollout_mechanism_changeset_function =
      Keyword.get(opts, :rollout_mechanism_changeset_function, :changeset)

    update_campaign
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> cast_polymorphic_embed(:rollout_mechanism,
      required: true,
      with: rollout_types_mfa(rollout_mechanism_changeset_function)
    )
  end

  defp rollout_types_mfa(changeset_function) do
    @rollout_mechanism_types
    |> Enum.map(fn {type, module} -> {type, {module, changeset_function, []}} end)
  end

  defp preserve_rollout_mechanism_type(_field, %t{} = _old_value, %t{} = _new_value), do: []

  defp preserve_rollout_mechanism_type(field, %t{} = _old_value, _new_value) do
    old_type_tuple = Enum.find(@rollout_mechanism_types, fn {_type_str, type} -> type == t end)
    {prev_type, _} = old_type_tuple

    [{field, "should be of the same type it was previously defined as, #{prev_type}"}]
  end
end
