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

defmodule EdgehogWeb.Context do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  def build_context(conn) do
    current_tenant = conn.assigns[:current_tenant]
    tenant_locale = current_tenant.default_locale
    preferred_locales = get_preferred_locales(conn)

    %{
      current_tenant: current_tenant,
      preferred_locales: preferred_locales,
      tenant_locale: tenant_locale
    }
  end

  defp get_preferred_locales(conn) do
    conn
    |> Plug.Conn.get_req_header("accept-language")
    |> Enum.flat_map(&get_locales/1)
    |> Enum.uniq()
  end

  defp get_locales(string) when is_binary(string) do
    ~r/[a-z]{2,3}-[A-Z]{2}/
    |> Regex.scan(string)
    |> List.flatten()
  end
end
