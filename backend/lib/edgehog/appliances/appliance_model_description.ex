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

defmodule Edgehog.Appliances.ApplianceModelDescription do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Appliances.ApplianceModel

  schema "appliance_model_descriptions" do
    field :text, :string
    field :locale, :string
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    belongs_to :appliance_model, ApplianceModel

    timestamps()
  end

  @doc false
  def changeset(appliance_model_description, attrs) do
    appliance_model_description
    |> cast(attrs, [:locale, :text])
    |> validate_required([:locale, :text])
    |> validate_format(:locale, ~r/^[a-z]{2,3}-[A-Z]{2}$/, message: "is not a valid locale")
    |> unique_constraint([:locale, :appliance_model_id, :tenant_id])
  end
end
