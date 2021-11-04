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

defmodule Edgehog.Astarte.Cluster do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Astarte.Realm

  schema "clusters" do
    field :base_api_url, :string
    field :name, :string
    has_many :realms, Realm

    timestamps()
  end

  @doc false
  def changeset(cluster, attrs) do
    cluster
    |> cast(attrs, [:name, :base_api_url])
    |> validate_required([:name, :base_api_url])
  end
end
