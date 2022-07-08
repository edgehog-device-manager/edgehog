#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.Devices.Device do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Astarte
  alias Edgehog.Devices.SystemModelPartNumber
  alias Edgehog.Labeling

  schema "devices" do
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    field :device_id, :string
    field :name, :string
    field :last_connection, :utc_datetime
    field :last_disconnection, :utc_datetime
    field :online, :boolean, default: false
    field :serial_number, :string
    belongs_to :realm, Astarte.Realm

    belongs_to :system_model_part_number, SystemModelPartNumber,
      foreign_key: :part_number,
      references: :part_number,
      type: :string

    has_one :system_model, through: [:system_model_part_number, :system_model]
    many_to_many :tags, Labeling.Tag, join_through: Labeling.DeviceTag, on_replace: :delete

    has_many :custom_attributes, Labeling.DeviceAttribute,
      where: [namespace: "custom"],
      on_replace: :delete

    timestamps()
  end

  @doc false
  def update_changeset(device, attrs) do
    device
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> cast_assoc(:custom_attributes, with: &Labeling.DeviceAttribute.custom_attribute_changeset/2)
  end
end
