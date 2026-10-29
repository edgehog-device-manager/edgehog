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

defmodule Edgehog.Containers.Image.Calculations.EffectiveRegistryAuth do
  @moduledoc """
  Returns the effective registry authentication payload for an image:
  the snapshotted `:registry_auth` for deployed copies, or the live
  `credentials.base64_json` for plain images.
  """

  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation

  @impl Calculation
  def load(_query, _opts, _context), do: [:registry_auth, credentials: [:base64_json]]

  @impl Calculation
  def calculate(images, _opts, _context) do
    Enum.map(images, fn image ->
      image.registry_auth || get_in(image.credentials.base64_json)
    end)
  end
end
