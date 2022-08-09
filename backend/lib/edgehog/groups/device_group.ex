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

  alias Edgehog.Selector

  schema "device_groups" do
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    field :handle, :string
    field :name, :string
    field :selector, :string

    timestamps()
  end

  @doc false
  def changeset(device_group, attrs) do
    device_group
    |> cast(attrs, [:name, :handle, :selector])
    |> validate_required([:name, :handle, :selector])
    |> validate_format(:handle, ~r/^[a-z][a-z\d\-]*$/,
      message:
        "should start with a lower case ASCII letter and only contain lower case ASCII letters, digits and -"
    )
    |> validate_change(:selector, &validate_selector/2)
    |> unique_constraint([:name, :tenant_id])
    |> unique_constraint([:handle, :tenant_id])
  end

  defp validate_selector(field, selector) do
    case Selector.to_ecto_query(selector) do
      {:ok, _ecto_query} ->
        []

      {:error, %Selector.Parser.Error{message: message}} ->
        msg = "failed to be parsed with error: " <> message
        [{field, msg}]
    end
  end
end
