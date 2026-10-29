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

defmodule Edgehog.Containers.Image.Changes.SnapshotRegistryAuth do
  @moduledoc """
  Snapshots the base64-encoded registry authentication payload from the
  source image's credentials onto the `:registry_auth` attribute when copying
  an `Edgehog.Containers.Image` for deployment.
  """

  use Ash.Resource.Change

  alias Edgehog.Containers.Image

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    with true <- changeset.valid?,
         nil <- Ash.Changeset.get_attribute(changeset, :registry_auth),
         source_image_id when is_binary(source_image_id) <-
           Ash.Changeset.get_attribute(changeset, :source_image_id),
         {:ok, source_image} <-
           Ash.get(Image, source_image_id, load: [credentials: [:base64_json]], tenant: tenant) do
      registry_auth = get_in(source_image.credentials.base64_json)
      Ash.Changeset.force_change_attribute(changeset, :registry_auth, registry_auth)
    else
      {:error, error} -> Ash.Changeset.add_error(changeset, error)
      _ -> changeset
    end
  end
end
