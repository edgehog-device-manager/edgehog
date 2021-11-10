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

defmodule Edgehog.Tenants.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Astarte.Realm

  @primary_key {:tenant_id, :id, autogenerate: true}
  schema "tenants" do
    field :name, :string
    field :slug, :string
    has_one :realm, Realm, foreign_key: :tenant_id

    timestamps()
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
    |> validate_format(:slug, ~r/^[a-z\d\-]+$/,
      message: "should only contain lower case ASCII letters (from a to z), digits and -"
    )
  end
end
