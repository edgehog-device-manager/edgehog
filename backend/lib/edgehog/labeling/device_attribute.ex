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

defmodule Edgehog.Labeling.DeviceAttribute do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "device_attributes" do
    field :tenant_id, :integer,
      autogenerate: {Edgehog.Repo, :get_tenant_id, []},
      primary_key: true

    field :device_id, :id, primary_key: true
    field :namespace, Ecto.Enum, values: [:custom], primary_key: true
    field :key, :string, primary_key: true
    field :typed_value, Ecto.JSONVariant

    timestamps()
  end

  @doc false
  def changeset(attributes, attrs) do
    attributes
    |> cast(attrs, [:namespace, :key, :typed_value])
    |> validate_required([:namespace, :key, :typed_value])
    |> validate_format(:key, ~r/[a-z0-9-_]+/)
  end

  @doc false
  def custom_attribute_changeset(attributes, attrs) do
    changeset(attributes, attrs)
    |> validate_inclusion(:namespace, [:custom])
  end
end
