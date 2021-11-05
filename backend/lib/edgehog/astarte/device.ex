#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind
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

  schema "devices" do
    field :device_id, :string
    field :name, :string
    field :tenant_id, :id
    belongs_to :realm, Realm

    timestamps()
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [:name, :device_id])
    |> validate_required([:name, :device_id])
    |> unique_constraint([:device_id, :realm_id, :tenant_id])
  end
end
