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

defmodule Edgehog.Astarte.Device.CreateContainerRequest do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.CreateContainerRequest.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Error

  @interface "io.edgehog.devicemanager.apps.CreateContainerRequest"

  @impl Edgehog.Astarte.Device.CreateContainerRequest.Behaviour
  def send_create_container_request(%AppEngine{} = client, device_id, request_data) do
    request_data = Map.from_struct(request_data)

    client
    |> AppEngine.Devices.send_datastream(
      device_id,
      @interface,
      "/container",
      request_data
    )
    |> Error.maybe_match_error(device_id, @interface)
  end
end
