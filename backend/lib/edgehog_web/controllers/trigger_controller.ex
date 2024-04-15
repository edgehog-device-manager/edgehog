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

defmodule EdgehogWeb.AstarteTriggerController do
  use EdgehogWeb, :controller

  action_fallback EdgehogWeb.FallbackController

  alias Edgehog.Triggers

  def process_event(conn, _params) do
    tenant = Ash.PlugHelpers.get_tenant(conn)

    realm_name = get_realm_name(conn)

    with :ok <- Triggers.handle_trigger(realm_name, conn.body_params, tenant: tenant) do
      send_resp(conn, :ok, "")
    end
  end

  defp get_realm_name(conn) do
    case get_req_header(conn, "astarte-realm") do
      [realm_name] -> realm_name
      _ -> nil
    end
  end
end
