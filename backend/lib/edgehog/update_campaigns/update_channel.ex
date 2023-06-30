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

defmodule Edgehog.UpdateCampaigns.UpdateChannel do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Groups

  schema "update_channels" do
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    field :handle, :string
    field :name, :string
    has_many :target_groups, Groups.DeviceGroup

    field :target_group_ids, {:array, :id}, virtual: true

    timestamps()
  end

  @doc false
  def create_changeset(update_channel, attrs) do
    update_channel
    |> changeset(attrs)
    |> validate_required([:target_group_ids])
  end

  @doc false
  def changeset(update_channel, attrs) do
    update_channel
    |> cast(attrs, [:name, :handle, :target_group_ids])
    |> validate_required([:name, :handle])
    |> validate_length(:target_group_ids, min: 1)
    |> unique_constraint([:handle, :tenant_id])
    |> unique_constraint([:name, :tenant_id])
    |> validate_format(:handle, ~r/^[a-z][a-z\d\-]*$/,
      message:
        "should start with a lower case ASCII letter and only contain lower case ASCII letters, digits and -"
    )
  end

  def default_preloads do
    [:target_groups]
  end
end
