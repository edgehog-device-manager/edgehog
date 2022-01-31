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

  alias Edgehog.Astarte

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "ota_operations" do
    field :base_image_url, :string

    field :status, Ecto.Enum,
      values: [pending: "Pending", in_progress: "InProgress", error: "Error", done: "Done"],
      default: :pending

    field :status_code, :string
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    field :manual?, :boolean, source: :is_manual
    belongs_to :device, Astarte.Device

    timestamps(type: :utc_datetime)
  end

  @doc false
  def create_changeset(ota_operation, attrs) do
    ota_operation
    |> cast(attrs, [:base_image_url, :status, :status_code])
    |> validate_required([:base_image_url])
  end

  @doc false
  def update_changeset(ota_operation, attrs) do
    ota_operation
    |> cast(attrs, [:status, :status_code])
  end
end
