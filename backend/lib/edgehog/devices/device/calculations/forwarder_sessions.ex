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

defmodule Edgehog.Devices.Device.Calculations.ForwarderSessions do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation

  @forwarder_session_module Application.compile_env(
                              :edgehog,
                              :astarte_forwarder_session_module,
                              Edgehog.Astarte.Device.ForwarderSession
                            )

  @impl Calculation
  def load(_query, _opts, _context) do
    [:device_id, :online, :appengine_client]
  end

  @impl Calculation
  def calculate(devices, _opts, _context) do
    Enum.map(devices, fn device ->
      %{
        device_id: device_id,
        online: online,
        appengine_client: appengine_client
      } = device

      if online do
        list_sessions(appengine_client, device_id)
      else
        []
      end
    end)
  end

  defp list_sessions(appengine_client, device_id) do
    case @forwarder_session_module.list_sessions(appengine_client, device_id) do
      {:ok, sessions} -> sessions
      {:error, _reason} -> []
    end
  end
end
