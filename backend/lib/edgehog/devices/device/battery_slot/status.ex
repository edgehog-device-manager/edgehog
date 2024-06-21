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

defmodule Edgehog.Devices.Device.BatterySlot.Status do
  use Ash.Type.Enum,
    values: [
      charging: "The battery is charging.",
      discharging: "The battery is discharging.",
      idle: "The battery is idle.",
      either_idle_or_charging: """
      The battery is either in a charging or in an idle state, \
      since the hardware doesn't allow to distinguish between them.
      """,
      failure: "The battery is in a failed state.",
      removed: "The battery is removed.",
      unknown: "The battery status cannot be determined."
    ]

  use AshGraphql.Type

  @impl AshGraphql.Type
  def graphql_type(_), do: :battery_slot_status

  def match("Charging"), do: {:ok, :charging}
  def match("Discharging"), do: {:ok, :discharging}
  def match("Idle"), do: {:ok, :idle}
  def match("EitherIdleOrCharging"), do: {:ok, :either_idle_or_charging}
  def match("Failure"), do: {:ok, :failure}
  def match("Removed"), do: {:ok, :removed}
  def match("Unknown"), do: {:ok, :unknown}
  def match(term), do: super(term)
end
