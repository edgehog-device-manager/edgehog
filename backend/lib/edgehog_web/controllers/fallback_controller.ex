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

  def call(conn, {:error, :missing_astarte_realm_header}) do
    conn
    |> put_status(:bad_request)
    |> put_view(EdgehogWeb.ErrorView)
    |> render(:"400")
  end

  def call(conn, {:error, :realm_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(EdgehogWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :cannot_process_device_event}) do
    conn
    |> put_status(422)
    |> put_view(EdgehogWeb.ErrorView)
    |> render(:"422")
  end
end
