#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Triggers.IncomingData.Handlers.AvailableEnvFiles do
  @moduledoc """
  Available EnvFiles handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, context) do
    %{realm_id: realm_id, device_id: device_id, tenant: tenant} = context

    device = Devices.fetch_device_by_identity!(device_id, realm_id, tenant: tenant)

    case String.split(event.path, "/") do
      ["", env_file_id, _field] -> handle_env_file_event(env_file_id, event.value, device, tenant)
      _ -> {:error, :invalid_event_path}
    end
  end

  defp handle_env_file_event(env_file_id, value, device, tenant) do
    env_file = Containers.fetch_env_file!(env_file_id, tenant: tenant)

    env_file =
      Ash.load!(env_file, [container_deployment: [:device_id]], tenant: tenant)

    if env_file.container_deployment.device_id != device.id do
      {:error, :device_mismatch}
    else
      update_env_file(env_file, value, tenant)
    end
  end

  defp update_env_file(env_file, nil, tenant) do
    Containers.destroy_env_file!(env_file, tenant: tenant)
    {:ok, env_file}
  end

  defp update_env_file(env_file, true, tenant) do
    Containers.mark_env_file_as_available(env_file, tenant: tenant)
  end

  defp update_env_file(env_file, false, tenant) do
    Containers.mark_env_file_as_unavailable(env_file, tenant: tenant)
  end

  defp update_env_file(env_file, _value, tenant) do
    Containers.mark_env_file_as_available(env_file, tenant: tenant)
  end
end
