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

defmodule Edgehog.Devices.SystemModelPartNumber do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Devices.SystemModel

  schema "system_model_part_numbers" do
    field :part_number, :string
    field :tenant_id, :id
    belongs_to :system_model, SystemModel

    timestamps()
  end

  @doc false
  def changeset(system_model_part_number, attrs) do
    system_model_part_number
    |> cast(attrs, [:part_number])
    |> validate_required([:part_number])
  end
end
