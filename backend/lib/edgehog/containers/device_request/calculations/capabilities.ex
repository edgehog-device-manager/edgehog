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

defmodule Edgehog.Containers.DeviceRequest.Calculations.Capabilities do
  @moduledoc false

  use Ash.Resource.Calculation

  @impl Ash.Resource.Calculation
  def load(_, _, _), do: [:db_capabilities]

  @impl Ash.Resource.Calculation
  def calculate(records, _, _) do
    Enum.map(records, fn record ->
      record.db_capabilities
      |> Kernel.||([])
      |> Enum.map(fn json ->
        Jason.decode!(json)
      end)
    end)
  end
end
