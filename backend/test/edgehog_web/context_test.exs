#
# This file is part of Edgehog.
#
# Copyright 2022-2023 SECO Mind Srl
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

defmodule EdgehogWeb.ContextTest do
  use EdgehogWeb.ConnCase

  alias EdgehogWeb.Context

  test "build_context/1 fetches preferred locales from accept-language header", %{
    conn: conn,
    tenant: tenant
  } do
    default_locale = tenant.default_locale
    conn = Plug.Conn.assign(conn, :current_tenant, tenant)

    language_headers = [
      {"accept-language", "it-IT,it;q=0.8,en-UK;q=0.6,en;q=0.4"},
      {"accept-language", "#{default_locale}"},
      {"accept-language", "fr-FR,fr;q=0.8,en-UK;q=0.6,en;q=0.4"}
    ]

    conn = %{conn | req_headers: conn.req_headers ++ language_headers}

    %{preferred_locales: preferred_locales, tenant_locale: tenant_locale} =
      Context.build_context(conn)

    assert ["it-IT", "en-UK", ^default_locale, "fr-FR"] = preferred_locales
    assert default_locale == tenant_locale
  end

  test "build_context/1 uses the tenant's default locale without accept-language headers", %{
    conn: conn,
    tenant: tenant
  } do
    default_locale = tenant.default_locale
    conn = Plug.Conn.assign(conn, :current_tenant, tenant)

    %{preferred_locales: [], tenant_locale: tenant_locale} = Context.build_context(conn)

    assert default_locale == tenant_locale
  end
end
