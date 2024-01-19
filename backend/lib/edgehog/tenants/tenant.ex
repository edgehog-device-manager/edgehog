#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  alias Edgehog.Validations

  code_interface do
    define_for Edgehog.Tenants
    define :create
    define :fetch_by_slug, action: :by_slug, args: [:slug]
    define :destroy
  end

  actions do
    defaults [:create, :read, :destroy]

    read :by_slug, get_by: :slug
  end

  attributes do
    integer_primary_key :tenant_id

    attribute :name, :string, allow_nil?: false
    attribute :slug, :string, allow_nil?: false
    attribute :default_locale, :string, default: "en-US"
    attribute :public_key, :string, allow_nil?: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_one :realm, Edgehog.Astarte.Realm do
      api Edgehog.Astarte
      source_attribute :tenant_id
    end
  end

  identities do
    identity :name, [:name]
    identity :slug, [:slug]
  end

  validations do
    validate Validations.slug(:slug)
    validate Validations.locale(:default_locale)
    validate {Validations.PEMPublicKey, attribute: :public_key}
  end

  postgres do
    table "tenants"
    repo Edgehog.Repo
  end
end
