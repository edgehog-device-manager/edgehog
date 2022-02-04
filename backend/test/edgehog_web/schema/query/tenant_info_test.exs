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

defmodule EdgehogWeb.Schema.Query.TenantInfoTest do
  use EdgehogWeb.ConnCase

  alias Edgehog.Tenants.Tenant

  describe "tenantInfo query" do
    @query """
    {
      tenantInfo {
        name
        slug
        defaultLocale
      }
    }
    """

    test "returns the tenant info", %{conn: conn, api_path: api_path, tenant: tenant} do
      conn = get(conn, api_path, query: @query)

      %Tenant{name: name, slug: slug, default_locale: default_locale} = tenant

      assert %{
               "data" => %{
                 "tenantInfo" => %{
                   "name" => ^name,
                   "slug" => ^slug,
                   "defaultLocale" => ^default_locale
                 }
               }
             } = json_response(conn, 200)
    end
  end
end
