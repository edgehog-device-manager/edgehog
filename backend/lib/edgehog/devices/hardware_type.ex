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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Devices.HardwareType do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Devices.HardwareTypePartNumber
  alias Edgehog.Devices.SystemModel

  schema "hardware_types" do
    field :handle, :string
    field :name, :string
    field :tenant_id, :id
    has_many :part_numbers, HardwareTypePartNumber, on_replace: :delete
    has_many :system_models, SystemModel

    timestamps()
  end

  @doc false
  def changeset(hardware_type, attrs) do
    hardware_type
    |> cast(attrs, [:name, :handle])
    |> validate_required([:name, :handle])
    |> unique_constraint([:name, :tenant_id])
    |> unique_constraint([:handle, :tenant_id])
    |> validate_format(:handle, ~r/^[a-z][a-z\d\-]*$/,
      message: "should only contain lower case ASCII letters (from a to z), digits and -"
    )
  end

  @doc false
  def delete_changeset(hardware_type) do
    hardware_type
    |> change()
    |> no_assoc_constraint(:system_models)
  end
end
