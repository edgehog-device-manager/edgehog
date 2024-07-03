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

defmodule Edgehog.Astarte.Device.BatteryStatus.BatterySlot do
  @moduledoc false
  defstruct [
    :slot,
    :level_percentage,
    :level_absolute_error,
    :status
  ]

  @type t() :: %__MODULE__{
          slot: String.t(),
          level_percentage: float() | nil,
          level_absolute_error: float() | nil,
          status: String.t()
        }
end
