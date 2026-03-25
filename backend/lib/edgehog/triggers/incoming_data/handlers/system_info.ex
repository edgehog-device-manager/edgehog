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

defmodule Edgehog.Triggers.IncomingData.Handlers.SystemInfo do
  @moduledoc """
  Available Images handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Ash.Astarte.Triggers.HandlerBehavior
  alias Edgehog.Devices.Device

  @impl HandlerBehavior
  def handle_event(%{path: "/serialNumber"} = event, _opts, context) do
    %{realm_id: realm_id, device_id: device_id, tenant: tenant} = context

    params = %{realm_id: realm_id, device_id: device_id, serial_number: event.value}

    Device
    |> Ash.Changeset.for_create(:from_serial_number_event, params)
    |> Ash.create(tenant: tenant)
  end

  @impl HandlerBehavior
  def handle_event(%{path: "/partNumber"} = event, _opts, context) do
    %{realm_id: realm_id, device_id: device_id, tenant: tenant} = context

    params = %{realm_id: realm_id, device_id: device_id, part_number: event.value}

    Device
    |> Ash.Changeset.for_create(:from_part_number_event, params)
    |> Ash.create(tenant: tenant)
  end
end
