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

defmodule Edgehog.Tenants.Tenant do
  use Ecto.Schema
  import Ecto.Changeset
  import Edgehog.ChangesetValidation

  alias Edgehog.Astarte.Realm

  @primary_key {:tenant_id, :id, autogenerate: true}
  schema "tenants" do
    field :name, :string
    field :slug, :string
    field :default_locale, :string, default: "en-US"
    field :public_key, :string
    has_one :realm, Realm, foreign_key: :tenant_id

    timestamps()
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug, :default_locale, :public_key])
    |> validate_required([:name, :slug, :public_key])
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
    |> validate_tenant_slug(:slug)
    |> validate_locale(:default_locale)
    |> validate_pem_public_key(:public_key)
  end
end
