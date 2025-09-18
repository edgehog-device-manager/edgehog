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

defmodule Edgehog.Astarte.Device.AvailableImages do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.AvailableImages.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.AvailableImages.ImageStatus

  @interface "io.edgehog.devicemanager.apps.AvailableImages"

  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @interface) do
      images = Enum.map(data, &parse_image_properties/1)

      {:ok, images}
    end
  end

  defp parse_image_properties({image_id, properties}) do
    %ImageStatus{
      id: image_id,
      pulled: properties["pulled"]
    }
  end
end
