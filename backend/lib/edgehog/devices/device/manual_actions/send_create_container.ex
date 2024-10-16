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

defmodule Edgehog.Devices.Device.ManualActions.SendCreateContainer do
  @moduledoc false
  use Ash.Resource.ManualUpdate

  alias Edgehog.Astarte.Device.CreateContainerRequest.RequestData

  @send_create_container_request_behaviour Application.compile_env(
                                             :edgehog,
                                             :astarte_create_container_request_module,
                                             Edgehog.Astarte.Device.CreateContainerRequest
                                           )

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    device = changeset.data

    with {:ok, container} <- Ash.load(changeset.container, :env_encoding) do
      env_encoding = container.env_encoding
      restart_policy = to_correct_string(container.restart_policy)

      data = %RequestData{
        container_id: container.id,
        image_id: container.image_id,
        networks_ids: [],
        volume_ids: [],
        hostname: container.hostname,
        restart_policy: restart_policy,
        env: env_encoding,
        binds: [],
        networks: [],
        port_bindings: [],
        privileged: container.privileged
      }

      with {:ok, device} <- Ash.load(device, :appengine_client) do
        @send_create_container_request_behaviour.send_create_container_request(
          device.appengine_client,
          device.device_id,
          data
        )
      end
    end
  end

  defp to_correct_string(atom), do: String.replace(atom, "_", "-")
end
