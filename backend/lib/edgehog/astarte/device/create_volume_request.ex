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

defmodule Edgehog.Astarte.Device.CreateVolumeRequest do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.CreateVolumeRequest.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Error.AstarteAPIError

  @interface "io.edgehog.devicemanager.apps.CreateVolumeRequest"

  @impl Edgehog.Astarte.Device.CreateVolumeRequest.Behaviour
  def send_create_volume_request(%AppEngine{} = client, device_id, request_data) do
    request_data = Map.from_struct(request_data)

    api_call =
      AppEngine.Devices.send_datastream(
        client,
        device_id,
        @interface,
        "/volume",
        request_data
      )

    with {:error, api_error} <- api_call do
      reason = AstarteAPIError.exception(status: api_error.status, response: api_error.response)

      {:error, reason}
    end
  end
end
