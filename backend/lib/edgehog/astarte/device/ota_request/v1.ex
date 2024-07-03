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

defmodule Edgehog.Astarte.Device.OTARequest.V1 do
  @behaviour Edgehog.Astarte.Device.OTARequest.V1.Behaviour

  alias Astarte.Client.AppEngine

  @interface "io.edgehog.devicemanager.OTARequest"

  @impl Edgehog.Astarte.Device.OTARequest.V1.Behaviour
  def update(%AppEngine{} = client, device_id, uuid, url) do
    data = %{operation: "Update", uuid: uuid, url: url}
    AppEngine.Devices.send_datastream(client, device_id, @interface, "/request", data)
  end

  @impl Edgehog.Astarte.Device.OTARequest.V1.Behaviour
  def cancel(%AppEngine{} = client, device_id, uuid) do
    data = %{operation: "Cancel", uuid: uuid}
    AppEngine.Devices.send_datastream(client, device_id, @interface, "/request", data)
  end
end
