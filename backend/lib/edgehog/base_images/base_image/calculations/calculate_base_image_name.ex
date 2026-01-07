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

defmodule Edgehog.BaseImages.BaseImage.Calculations.CalculateBaseImageName do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation

  @impl Calculation
  def load(_query, _opts, _context) do
    [:version, :localized_release_display_names]
  end

  @impl Calculation
  def calculate(records, _opts, _context) do
    Enum.map(records, fn base_image ->
      #  TODO: for now, only one translation can be present so we take it directly.
      display_name =
        case base_image.localized_release_display_names do
          [%{value: value} | _] -> value
          _ -> nil
        end

      "#{base_image.version} (#{display_name})"
    end)
  end
end
