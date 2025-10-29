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

defmodule Edgehog.Astarte.Device.AvailableVolumes do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.AvailableVolumes.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.AvailableVolumes.VolumeStatus

  @interface "io.edgehog.devicemanager.apps.AvailableVolumes"

  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @interface) do
      volumes = Enum.map(data, &parse_volume_properties/1)

      {:ok, volumes}
    end
  end

  defp parse_volume_properties({volume_id, properties}) do
    %VolumeStatus{
      id: volume_id,
      created: properties["created"]
    }
  end
end
