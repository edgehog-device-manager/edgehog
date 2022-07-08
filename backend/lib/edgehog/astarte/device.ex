#
# This file is part of Edgehog.
#
# Copyright 2021-2022 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Astarte.Realm

  schema "devices" do
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    field :device_id, :string
    field :name, :string
    field :last_connection, :utc_datetime
    field :last_disconnection, :utc_datetime
    field :online, :boolean, default: false
    field :serial_number, :string
    field :part_number, :string
    belongs_to :realm, Realm
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
      :online,
      :last_connection,
      :last_disconnection,
      :serial_number,
      :part_number
    ])
  end
end
