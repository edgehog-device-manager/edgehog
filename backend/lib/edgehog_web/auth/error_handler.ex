#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule EdgehogWeb.Auth.ErrorHandler do
  @behaviour Guardian.Plug.ErrorHandler

  import Plug.Conn
  require Logger

  @impl true
  # This is called when no JWT token is present
  def auth_error(conn, {:unauthenticated, reason}, _opts) do
    _ = Logger.info("Refusing unauthenticated request: #{inspect(reason)}.")

    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.put_view(EdgehogWeb.ErrorView)
    |> Phoenix.Controller.render(:"401")
    |> halt()
  end

  # In all other cases, we reply with 403
  def auth_error(conn, _reason, _opts) do
    conn
    |> put_status(:forbidden)
    |> Phoenix.Controller.put_view(EdgehogWeb.ErrorView)
    |> Phoenix.Controller.render(:"403")
    |> halt()
  end
end
