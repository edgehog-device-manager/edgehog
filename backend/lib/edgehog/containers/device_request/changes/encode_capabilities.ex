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

defmodule Edgehog.Containers.DeviceRequest.Changes.EncodeCapabilities do
  @moduledoc """
  Encodes the `:capabilities` argument (a list of capability lists) into JSON
  strings stored in the `:db_capabilities` attribute.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    capabilities =
      changeset
      |> Ash.Changeset.get_argument(:capabilities)
      |> Kernel.||([])
      |> Enum.map(&Jason.encode!/1)

    Ash.Changeset.change_attribute(changeset, :db_capabilities, capabilities)
  end
end
