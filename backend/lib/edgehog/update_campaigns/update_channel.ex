#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.UpdateChannel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "update_channels" do
    field :handle, :string
    field :name, :string
    field :tenant_id, :id

    timestamps()
  end

  @doc false
  def changeset(update_channel, attrs) do
    update_channel
    |> cast(attrs, [:name, :handle])
    |> validate_required([:name, :handle])
    |> unique_constraint(:handle)
    |> unique_constraint(:name)
  end
end
