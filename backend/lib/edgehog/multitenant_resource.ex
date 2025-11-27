#
# This file is part of Edgehog.
#
# Copyright 2023-2024 SECO Mind Srl
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

defmodule Edgehog.MultitenantResource do
  @moduledoc false
  alias Edgehog.Tenants.Tenant

  @custom_opts [:tenant_id_in_primary_key?]

  defmacro __using__(opts) do
    quote do
      use Ash.Resource,
          unquote(
            opts
            |> Keyword.drop(@custom_opts)
            |> Keyword.put_new(:data_layer, AshPostgres.DataLayer)
          )

      relationships do
        belongs_to :tenant, Tenant do
          allow_nil? false
          destination_attribute :tenant_id
          primary_key? unquote(Keyword.get(opts, :tenant_id_in_primary_key?, false))
        end
      end

      multitenancy do
        strategy :attribute
        attribute :tenant_id
      end

      postgres do
        repo Edgehog.Repo

        references do
          reference :tenant, on_delete: :delete
        end

        # We have to create a unique index on `[:id, :tenant_id]` to be able to use composite
        # foreign keys (i.e. `with: [tenant_id: :tenant_id]`).
        # We have to wrap this in an `if` because some resources (e.g. many-to-many join tables
        # like `devices_tags`) don't have a single :id primary key. Those resources manually add
        # `:tenant_id` in their primary key, which is why we check for that to avoid creating
        # the index
        if !unquote(Keyword.get(opts, :tenant_id_in_primary_key?, false)) do
          custom_indexes do
            # Assumptions:
            # - There is a primary key and it's called :id
            # We use `all_tenants?: true` so we can control the order of the index and be
            # consistent with the indexes that were created when using Ecto manually
            index [:id, :tenant_id], unique: true, all_tenants?: true
          end
        end

        # Note that the two custom_indexes sections are merged if they're both present
        custom_indexes do
          # We use `all_tenants?: true` otherwise it would result in [:tenant_id, :tenant_id]
          index [:tenant_id], all_tenants?: true
        end
      end
    end
  end
end
