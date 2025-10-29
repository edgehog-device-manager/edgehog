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

defmodule EdgehogWeb.PopulateTenant do
  @moduledoc false
  @behaviour Plug

  import Plug.Conn

  alias Ash.Error.Query.NotFound
  alias Edgehog.Tenants

  def init(opts), do: opts

  def call(conn, _opts) do
    tenant_slug = conn.path_params["tenant_slug"]

    case Tenants.fetch_tenant_by_slug(tenant_slug) do
      {:ok, tenant} ->
        Ash.PlugHelpers.set_tenant(conn, tenant)

      {:error, %Ash.Error.Invalid{errors: [%NotFound{} | _]}} ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.put_view(EdgehogWeb.ErrorView)
        |> Phoenix.Controller.render("403.json")
        |> halt()

      {:error, %NotFound{}} ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.put_view(EdgehogWeb.ErrorView)
        |> Phoenix.Controller.render("403.json")
        |> halt()
    end
  end
end
