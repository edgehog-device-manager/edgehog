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

defmodule Edgehog.Mocks.Astarte.Device.SystemStatus do
  @behaviour Edgehog.Astarte.Device.SystemStatus.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.SystemStatus

  @impl true
  def get(%AppEngine{} = _client, _device_id) do
    system_status = %SystemStatus{
      boot_id: "1c0cf72f-8428-4838-8626-1a748df5b889",
      memory_free_bytes: 166_772,
      task_count: 12,
      uptime_milliseconds: 5785,
      timestamp: ~U[2021-11-15 11:44:57.432516Z]
    }

    {:ok, system_status}
  end
end
