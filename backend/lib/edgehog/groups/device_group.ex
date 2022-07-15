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

defmodule Edgehog.Groups.DeviceGroup do
  use Ecto.Schema
  import Ecto.Changeset

  schema "device_groups" do
    field :handle, :string
    field :name, :string
    field :selector, :string
    field :tenant_id, :id

    timestamps()
  end

  @doc false
  def changeset(device_group, attrs) do
    device_group
    |> cast(attrs, [:name, :handle, :selector])
    |> validate_required([:name, :handle, :selector])
  end
end
