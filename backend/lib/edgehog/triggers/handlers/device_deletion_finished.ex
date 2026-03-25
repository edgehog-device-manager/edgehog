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

defmodule Edgehog.Triggers.Handlers.DeviceDeletionFinished do
  @moduledoc """
  Device deletion finished handler.
  """

  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Devices.Device

  require Ash.Query

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(_event, _opts, context) do
    %{realm_id: realm_id, device_id: device_id, tenant: tenant} = context

    device_query = Ash.Query.filter(Device, device_id == ^device_id and realm_id == ^realm_id)

    # here uniqueness is guaranteed by :unique_realm_device_id identity on
    # Devices
    with {:ok, device} <- Ash.read_one(device_query, tenant: tenant, not_found_error?: true) do
      Ash.destroy(device)
    end
  end
end
