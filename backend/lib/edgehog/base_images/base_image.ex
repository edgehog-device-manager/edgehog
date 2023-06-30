#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.BaseImages.BaseImage do
  use Ecto.Schema
  use I18nHelpers.Ecto.TranslatableFields
  import Ecto.Changeset
  import Edgehog.Localization.Validation

  alias Edgehog.BaseImages.BaseImageCollection

  @type t :: Ecto.Schema.t()

  schema "base_images" do
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    translatable_field :description
    translatable_field :release_display_name
    field :starting_version_requirement, :string
    field :url, :string
    field :version, :string
    translatable_belongs_to :base_image_collection, BaseImageCollection

    timestamps()
  end

  @doc false
  def create_changeset(base_image, attrs) do
    base_image
    |> cast(attrs, [:version, :release_display_name, :description, :starting_version_requirement])
    |> validate_required([:version])
    |> unique_constraint([:version, :base_image_collection_id, :tenant_id])
    |> validate_change(:version, &validate_version/2)
    |> validate_change(:starting_version_requirement, &validate_version_requirement/2)
    |> validate_change(:description, &validate_locale/2)
    |> validate_change(:release_display_name, &validate_locale/2)
  end

  @doc false
  def update_changeset(base_image, attrs) do
    base_image
    |> cast(attrs, [:release_display_name, :description, :starting_version_requirement])
    |> validate_change(:starting_version_requirement, &validate_version_requirement/2)
    |> validate_change(:description, &validate_locale/2)
    |> validate_change(:release_display_name, &validate_locale/2)
  end

  defp validate_version(field, value) do
    case Version.parse(value) do
      {:ok, _version} ->
        []

      :error ->
        [{field, "is not a valid version"}]
    end
  end

  defp validate_version_requirement(field, value) do
    case Version.parse_requirement(value) do
      {:ok, _version} ->
        []

      :error ->
        [{field, "is not a valid version requirement"}]
    end
  end

  def default_preloads do
    [
      base_image_collection: [
        system_model: [:hardware_type, :part_numbers]
      ]
    ]
  end
end
