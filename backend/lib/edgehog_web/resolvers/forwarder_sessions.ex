#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule EdgehogWeb.Resolvers.ForwarderSessions do
  alias Edgehog.Devices
  alias Edgehog.Forwarder

  @doc """
  Fetches a forwarder session by its token and the device ID
  """
  def find_forwarder_session(%{device_id: device_id, session_token: session_token}, _resolution) do
    device =
      device_id
      |> Devices.get_device!()
      |> Devices.preload_astarte_resources_for_device()

    with {:error, :forwarder_session_not_found} <-
           Forwarder.fetch_forwarder_session(device, session_token) do
      {:ok, nil}
    end
  end

  @doc """
  Requests a forwarder session for the specified device ID.
  """
  def request_forwarder_session(%{device_id: device_id}, _resolution) do
    device =
      device_id
      |> Devices.get_device!()
      |> Devices.preload_astarte_resources_for_device()

    with {:ok, session_token} <-
           Forwarder.fetch_or_request_available_forwarder_session_token(device) do
      {:ok, %{session_token: session_token}}
    end
  end
end
