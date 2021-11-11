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

defmodule Edgehog.Appliances.ApplianceModelPartNumber do
  use Ecto.Schema
  import Ecto.Changeset

  schema "appliance_model_part_numbers" do
    field :part_number, :string
    field :appliance_model_id, :id
    field :tenant_id, :id

    timestamps()
  end

  @doc false
  def changeset(appliance_model_part_number, attrs) do
    appliance_model_part_number
    |> cast(attrs, [:part_number])
    |> validate_required([:part_number])
  end
end
