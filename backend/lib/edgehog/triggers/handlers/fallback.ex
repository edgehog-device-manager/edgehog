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

defmodule Edgehog.Triggers.Handlers.Fallback do
  @moduledoc """
  Fallback handler.
  """

  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Devices.Device

  require Logger

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, context) do
    %{tenant: tenant, realm_id: realm_id, device_id: device_id} = context

    Logger.debug("Unhandled event.", event: event, context: context)

    Device
    |> Ash.Changeset.for_create(:from_unhandled_event, %{realm_id: realm_id, device_id: device_id})
    |> Ash.create(tenant: tenant)
  end
end
