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
#

defmodule Edgehog.Devices.Device.ManualActions.SendCreateDeviceRequest do
  @moduledoc false

  use Ash.Resource.ManualUpdate

  alias Edgehog.Astarte.Device.CreateDeviceRequestRequest
  alias Edgehog.Astarte.Device.CreateDeviceRequestRequest.RequestData

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    device = changeset.data

    with {:ok, deployment} <- Ash.Changeset.fetch_argument(changeset, :deployment),
         {:ok, device_request} <- Ash.Changeset.fetch_argument(changeset, :device_request),
         {:ok, device_request} <- Ash.load(device_request, :capabilities),
         {:ok, device} <- Ash.load(device, :appengine_client) do
      data = %RequestData{
        id: device_request.id,
        deploymentId: deployment.id,
        driver: device_request.driver || "",
        count: device_request.count,
        deviceIds: device_request.device_ids,
        capabilities: device_request.db_capabilities,
        optionKeys: Map.keys(device_request.options),
        optionValues: Map.values(device_request.options)
      }

      with :ok <-
             CreateDeviceRequestRequest.send_create_device_request_request(
               device.appengine_client,
               device.device_id,
               data
             ) do
        {:ok, device}
      end
    end
  end
end
