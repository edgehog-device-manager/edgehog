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

defmodule Edgehog.Forwarder do
  @moduledoc """
  The Forwarder context.
  """

  alias Edgehog.Astarte.Device.ForwarderSession
  alias Edgehog.Devices
  alias Edgehog.Devices.Device

  @forwarder_session_module Application.compile_env(
                              :edgehog,
                              :astarte_forwarder_session_module,
                              ForwarderSession
                            )

  defp forwarder_hostname do
    forwarder_config = Application.fetch_env!(:edgehog, :edgehog_forwarder)
    forwarder_config.hostname
  end

  defp forwarder_port do
    forwarder_config = Application.fetch_env!(:edgehog, :edgehog_forwarder)
    forwarder_config.port
  end

  defp forwarder_secure_sessions? do
    forwarder_config = Application.fetch_env!(:edgehog, :edgehog_forwarder)
    forwarder_config.secure_sessions?
  end

  defp forwarder_enabled? do
    forwarder_config = Application.fetch_env!(:edgehog, :edgehog_forwarder)
    forwarder_config.enabled?
  end

  defp validate_forwarder_enabled do
    if forwarder_enabled?() do
      :ok
    else
      {:error, :edgehog_forwarder_disabled}
    end
  end

  defp validate_device_connected(%Device{online: true}), do: :ok
  defp validate_device_connected(%Device{online: false}), do: {:error, :device_disconnected}

  defp list_forwarder_sessions(%Device{} = device) do
    with :ok <- validate_forwarder_enabled(),
         :ok <- validate_device_connected(device),
         {:ok, appengine_client} <- Devices.appengine_client_from_device(device) do
      @forwarder_session_module.list_sessions(appengine_client, device.device_id)
    end
  end

  def fetch_forwarder_session(%Device{} = device, session_token) do
    with :ok <- validate_forwarder_enabled(),
         :ok <- validate_device_connected(device),
         {:ok, appengine_client} <- Devices.appengine_client_from_device(device) do
      @forwarder_session_module.fetch_session(appengine_client, device.device_id, session_token)
    end
  end

  defp request_forwarder_session(%Device{} = device, session_token) do
    with :ok <- validate_forwarder_enabled(),
         :ok <- validate_device_connected(device),
         {:ok, appengine_client} <- Devices.appengine_client_from_device(device) do
      @forwarder_session_module.request_session(
        appengine_client,
        device.device_id,
        session_token,
        forwarder_hostname(),
        forwarder_port(),
        forwarder_secure_sessions?()
      )
    end
  end

  defp fetch_available_forwarder_session(%Device{} = device) do
    with {:ok, forwarder_sessions} <- list_forwarder_sessions(device) do
      connected_session = Enum.find(forwarder_sessions, &(&1.status == :connected))
      connecting_session = Enum.find(forwarder_sessions, &(&1.status == :connecting))

      cond do
        connected_session != nil -> {:ok, connected_session}
        connecting_session != nil -> {:ok, connecting_session}
        true -> {:error, :forwarder_session_not_found}
      end
    end
  end

  def fetch_or_request_available_forwarder_session_token(%Device{} = device) do
    case fetch_available_forwarder_session(device) do
      {:ok, session} ->
        {:ok, session.token}

      {:error, :forwarder_session_not_found} ->
        session_token = Ecto.UUID.generate()

        with :ok <- request_forwarder_session(device, session_token) do
          {:ok, session_token}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
