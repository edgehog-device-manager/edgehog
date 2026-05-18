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

defmodule Edgehog.Astarte.Device.FileDeleteRequest do
  @moduledoc """
  Module responsible for handling file deletion requests on Astarte devices.
  """

  @behaviour Edgehog.Astarte.Device.FileDeleteRequest.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Error

  @interface "io.edgehog.devicemanager.storage.DeleteFile"

  @impl Edgehog.Astarte.Device.FileDeleteRequest.Behaviour
  def request_deletion(%AppEngine{} = client, device_id, request_data) do
    client
    |> AppEngine.Devices.send_datastream(
      device_id,
      @interface,
      "/request",
      Map.from_struct(request_data)
    )
    |> Error.maybe_match_error(device_id, @interface)
  end
end
