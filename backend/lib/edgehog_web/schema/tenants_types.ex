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

defmodule EdgehogWeb.Schema.TenantsTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias EdgehogWeb.Resolvers

  @desc """
  Represents information about a tenant
  """
  object :tenant_info do
    @desc "The tenant name"
    field :name, non_null(:string)

    @desc "The tenant slug"
    field :slug, non_null(:string)

    @desc "The default locale supported by the tenant"
    field :default_locale, non_null(:string)
  end

  object :tenants_queries do
    @desc "Retrieves information about the current tenant"
    field :tenant_info, non_null(:tenant_info) do
      resolve &Resolvers.Tenants.get_current_tenant/2
    end
  end
end
