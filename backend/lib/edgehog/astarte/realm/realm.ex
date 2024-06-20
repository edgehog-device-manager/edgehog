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

defmodule Edgehog.Astarte.Realm do
  use Edgehog.MultitenantResource,
    domain: Edgehog.Astarte

  alias Edgehog.Astarte.Realm
  alias Edgehog.Validations

  actions do
    defaults [:read, :destroy]

    read :global do
      multitenancy :allow_global
    end

    create :create do
      primary? true
      accept [:name, :private_key, :cluster_id]
    end
  end

  validations do
    validate Validations.realm_name(:name) do
      where changing(:name)
    end

    validate {Validations.PEMPrivateKey, attribute: :private_key} do
      where changing(:private_key)
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :private_key, :string do
      public? true
      allow_nil? false
      sensitive? true
      constraints trim?: false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :cluster, Edgehog.Astarte.Cluster do
      allow_nil? false
    end
  end

  calculations do
    calculate :realm_management_client, :struct, Realm.Calculations.RealmManagementClient do
      constraints instance_of: Astarte.Client.RealmManagement
      filterable? false
    end
  end

  identities do
    identity :name_tenant_id, [:name, :tenant_id]
    identity :name_cluster_id, [:name, :cluster_id]
  end

  postgres do
    table "realms"
    repo Edgehog.Repo
  end
end
