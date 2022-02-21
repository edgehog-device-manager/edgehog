#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Astarte.Realm
  alias Edgehog.Devices

  schema "devices" do
    field :device_id, :string
    field :name, :string
    field :tenant_id, :id
    field :last_connection, :utc_datetime
    field :last_disconnection, :utc_datetime
    field :online, :boolean, default: false
    field :serial_number, :string
    belongs_to :realm, Realm

    belongs_to :system_model_part_number, Devices.SystemModelPartNumber,
      foreign_key: :part_number,
      references: :part_number,
      type: :string

    has_one :system_model, through: [:system_model_part_number, :system_model]

    timestamps()
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [
      :name,
      :device_id,
      :online,
      :last_connection,
      :last_disconnection,
      :serial_number,
      :part_number
    ])
    |> validate_required([:name, :device_id])
    |> unique_constraint([:device_id, :realm_id, :tenant_id])
  end

  @doc false
  def update_changeset(device, attrs) do
    device
    |> cast(attrs, [
      :name,
      :online,
      :last_connection,
      :last_disconnection,
      :serial_number,
      :part_number
    ])
    |> validate_required([:name])
  end
end
