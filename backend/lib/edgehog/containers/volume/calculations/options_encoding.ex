#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Volume.Calculations.OptionsEncoding do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl Ash.Resource.Calculation
  def calculate(records, _opts, _context) do
    Enum.map(records, &encode_options(&1.options))
  end

  defp encode_options(options) do
    Enum.map(options, fn {key, value} ->
      to_string(key) <> "=" <> to_string(value)
    end)
  end
end
