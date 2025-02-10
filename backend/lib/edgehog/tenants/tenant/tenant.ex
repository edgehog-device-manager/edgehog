#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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
  @moduledoc false
  use Ash.Resource,
    domain: Edgehog.Tenants,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshGraphql.Resource,
      AshJsonApi.Resource
    ]

  alias Ash.Error.Invalid.TenantRequired
  alias Edgehog.Tenants.AstarteConfig
  alias Edgehog.Tenants.Tenant
  alias Edgehog.Tenants.Tenant.Changes
  alias Edgehog.Validations

  require Ash.Query

  @type record :: Ash.Resource.record()

  graphql do
    type :tenant_info

    # We don't care about filtering here
    derive_filter? false
    # :tenant_id, the primary key, already gets exposed as ID, so we hide it here
    # to avoid showing it twice. We also hide the public key to be consistent with
    # the old API
    hide_fields [:tenant_id, :public_key]
  end

  json_api do
    type "tenant"

    routes do
      base "/tenants"

      index :read
      post :provision
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :slug, :public_key, :default_locale]
    end

    read :current_tenant do
      description "Retrieves the current tenant."
      get? true

      prepare fn query, _context ->
        if query.tenant do
          Ash.Query.filter(query, tenant_id: query.tenant.tenant_id)
        else
          Ash.Query.add_error(
            query,
            TenantRequired.exception(resource: query.resource)
          )
        end
      end
    end

    create :provision do
      accept [:name, :slug, :public_key, :default_locale]
      argument :astarte_config, AstarteConfig, allow_nil?: false

      change Tenant.Changes.ProvisionAstarteResources
      change Tenant.Changes.TriggerReconciliation
    end

    action :reconcile, :term do
      argument :tenant, :struct do
        allow_nil? false
        constraints instance_of: __MODULE__
      end

      run Tenant.ManualActions.ReconcilerAction
    end

    destroy :destroy do
      description "Destroy tenant handling resource cleanup."

      require_atomic? false
      change Changes.HandleCleanup
    end
  end

  validations do
    validate Validations.slug(:slug) do
      where changing(:slug)
    end

    validate Validations.locale(:default_locale) do
      where changing(:default_locale)
    end

    validate {Validations.PEMPublicKey, attribute: :public_key} do
      where changing(:public_key)
    end
  end

  attributes do
    integer_primary_key :tenant_id

    attribute :name, :string do
      public? true
      description "The tenant name."
      allow_nil? false
    end

    attribute :slug, :string do
      public? true
      description "The tenant slug."
      allow_nil? false
    end

    attribute :default_locale, :string do
      public? true
      description "The default locale supported by the tenant."
      allow_nil? false
      default "en-US"
    end

    attribute :public_key, :string do
      public? true
      description "The tenant public key."
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_one :realm, Edgehog.Astarte.Realm do
      public? true
      source_attribute :tenant_id
      allow_nil? false
    end
  end

  identities do
    identity :name, [:name]
    identity :slug, [:slug]
  end

  postgres do
    table "tenants"
    repo Edgehog.Repo
  end

  defimpl Ash.ToTenant do
    def to_tenant(tenant, _resource), do: tenant.tenant_id
  end
end
