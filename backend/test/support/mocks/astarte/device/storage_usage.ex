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

defmodule Edgehog.Mocks.Astarte.Device.StorageUsage do
  @behaviour Edgehog.Astarte.Device.StorageUsage.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.StorageUsage.StorageUnit

  @impl true
  def get(%AppEngine{} = _client, _device_id) do
    storage_units = [
      %StorageUnit{
        label: "Disk 0",
        total_bytes: 348_360_704,
        free_bytes: 281_360_704
      }
    ]

    {:ok, storage_units}
  end
end
