#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule EdgehogWeb.FallbackController do
  use EdgehogWeb, :controller

  require Logger

  def call(conn, {:error, %Ash.Error.Invalid{} = error}) do
    cond do
      missing_realm?(error) ->
        conn
        |> put_status(:bad_request)
        |> put_view(EdgehogWeb.ErrorView)
        |> render(:"400")

      realm_not_found?(error) ->
        conn
        |> put_status(:not_found)
        |> put_view(EdgehogWeb.ErrorView)
        |> render(:"404")

      true ->
        Logger.notice("Error while handling trigger: #{inspect(error)}")

        conn
        |> put_status(422)
        |> put_view(EdgehogWeb.ErrorView)
        |> render(:"422")
    end
  end

  defp missing_realm?(error) do
    Enum.any?(error.errors, &match?(%Ash.Error.Changes.Required{field: :realm_name}, &1))
  end

  defp realm_not_found?(error) do
    Enum.any?(
      error.errors,
      &match?(%Ash.Error.Query.NotFound{resource: Edgehog.Astarte.Realm}, &1)
    )
  end
end
