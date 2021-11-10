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

defmodule Edgehog.Appliances.ApplianceModel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "appliance_models" do
    field :handle, :string
    field :name, :string
    field :tenant_id, :id
    field :hardware_type_id, :id

    timestamps()
  end

  @doc false
  def changeset(appliance_model, attrs) do
    appliance_model
    |> cast(attrs, [:name, :handle])
    |> validate_required([:name, :handle])
  end
end
