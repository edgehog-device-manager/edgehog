#
# This file is part of Edgehog.
#
# Copyright 2022-2023 SECO Mind Srl
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

defmodule Edgehog.BaseImages.BaseImageCollection do
  use Ecto.Schema
  use I18nHelpers.Ecto.TranslatableFields
  import Ecto.Changeset

  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.Devices

  schema "base_image_collections" do
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    field :handle, :string
    field :name, :string
    translatable_belongs_to :system_model, Devices.SystemModel
    translatable_has_many :base_images, BaseImage

    timestamps()
  end

  @doc false
  def changeset(base_image_collection, attrs) do
    base_image_collection
    |> cast(attrs, [:name, :handle])
    |> validate_required([:name, :handle])
    |> unique_constraint([:system_model_id, :tenant_id])
    |> unique_constraint([:name, :tenant_id])
    |> unique_constraint([:handle, :tenant_id])
    |> validate_format(:handle, ~r/^[a-z][a-z\d\-]*$/,
      message:
        "should start with a lower case ASCII letter and only contain lower case ASCII letters, digits and -"
    )
  end
end
