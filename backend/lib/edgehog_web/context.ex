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

defmodule EdgehogWeb.Context do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  defp build_context(conn) do
    current_tenant = get_current_tenant(conn)

    %{current_tenant: current_tenant}
    |> maybe_put_locale(conn)
  end

  defp get_current_tenant(conn) do
    conn.assigns[:current_tenant]
  end

  defp maybe_put_locale(context, conn) do
    case Plug.Conn.get_req_header(conn, "accept-language") do
      # If no header or *, we don't add an explicit locale
      [] ->
        context

      ["*" | _] ->
        context

      # If there's one (or more) accept-language, we use the first one
      [language | _] ->
        [locale | _] = String.split(language, ",", parts: 2)

        Map.put(context, :locale, locale)
    end
  end
end
