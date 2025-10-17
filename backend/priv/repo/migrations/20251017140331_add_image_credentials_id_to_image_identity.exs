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

defmodule Edgehog.Repo.Migrations.AddImageCredentialsIdToImageIdentity do
  @moduledoc """
  Make unique constraint include image_credentials_id so same image reference can be used with different credentials.
  """
  use Ecto.Migration

  def up do
    drop_if_exists unique_index(:images, [:tenant_id, :reference], name: "images_reference_index")

    create unique_index(:images, [:tenant_id, :reference, :image_credentials_id],
             name: "images_reference_credentials_index"
           )
  end

  def down do
    drop_if_exists unique_index(:images, [:tenant_id, :reference, :image_credentials_id],
                     name: "images_reference_credentials_index"
                   )

    IO.warn("""
    Skipping recreation of images_reference_index because duplicates
    may exist for (tenant_id, reference). Please clean up manually if needed.
    """)
  end
end
