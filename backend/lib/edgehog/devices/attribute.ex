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

defmodule Edgehog.Devices.Attribute do
  use Ecto.Schema
  import Ecto.Changeset

  schema "device_attributes" do
    field :key, :string
    field :namespace, Ecto.Enum, values: [:custom]
    field :typed_value, :map
    field :tenant_id, :id
    field :device_id, :id

    timestamps()
  end

  @doc false
  def changeset(attributes, attrs) do
    attributes
    |> cast(attrs, [:namespace, :key, :typed_value])
    |> validate_required([:namespace, :key, :typed_value])
  end
end
