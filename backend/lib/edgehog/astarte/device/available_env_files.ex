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

defmodule Edgehog.Astarte.Device.AvailableEnvFiles do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.AvailableEnvFiles.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.AvailableEnvFiles.EnvFileStatus

  @interface "io.edgehog.devicemanager.apps.AvailableEnvFiles"

  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @interface) do
      env_files = Enum.map(data, &parse_env_file_properties/1)

      {:ok, env_files}
    end
  end

  defp parse_env_file_properties({env_file_id, _properties}) do
    %EnvFileStatus{
      id: env_file_id
    }
  end
end
