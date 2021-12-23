#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.OSManagement.OTAOperation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ota_operations" do
    field :image_url, :string
    field :status, :string
    field :status_code, :string
    field :tenant_id, :binary_id
    field :device_id, :binary_id

    timestamps()
  end

  @doc false
  def changeset(ota_operation, attrs) do
    ota_operation
    |> cast(attrs, [:image_url, :status, :status_code])
    |> validate_required([:image_url, :status, :status_code])
  end
end
