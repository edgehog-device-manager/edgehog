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
  import Ecto.Changeset

  schema "base_images" do
    field :description, :map
    field :release_display_name, :map
    field :starting_version_requirement, :string
    field :version, :string
    field :base_image_collection_id, :id
    field :tenant_id, :id

    timestamps()
  end

  @doc false
  def changeset(base_image, attrs) do
    base_image
    |> cast(attrs, [:version, :release_display_name, :description, :starting_version_requirement])
    |> validate_required([
      :version,
      :release_display_name,
      :description,
      :starting_version_requirement
    ])
    |> unique_constraint(:version)
  end
end
