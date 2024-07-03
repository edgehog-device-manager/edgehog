#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device.OSInfo do
  @type t :: %__MODULE__{
          name: String.t() | nil,
          version: String.t() | nil
        }

  @enforce_keys [:name, :version]
  defstruct @enforce_keys

  @behaviour Edgehog.Astarte.Device.OSInfo.Behaviour

  alias Astarte.Client.AppEngine

  @interface "io.edgehog.devicemanager.OSInfo"

  @impl Edgehog.Astarte.Device.OSInfo.Behaviour
  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_properties_data(client, device_id, @interface) do
      os_info = parse_data(data)

      {:ok, os_info}
    end
  end

  def parse_data(data) do
    %__MODULE__{
      name: data["osName"],
      version: data["osVersion"]
    }
  end
end
