#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Image.Calculations.Dangling do
  @moduledoc false
  use Ash.Resource.Calculation

  import Ash.Expr

  require Ash.Query

  @impl Ash.Resource.Calculation
  def calculate(records, _opts, context) do
    image_ids = Enum.map(records, & &1.id)
    tenant = Map.get(context, :tenant)

    containers =
      Edgehog.Containers.Container
      |> Ash.Query.filter(expr(image_id in ^image_ids))
      |> Ash.read!(tenant: tenant)

    referenced_image_ids = Enum.map(containers, & &1.image_id)

    Enum.map(records, fn image ->
      image.id not in referenced_image_ids
    end)
  end
end
