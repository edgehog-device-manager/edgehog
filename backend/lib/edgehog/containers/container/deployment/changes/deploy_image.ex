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

defmodule Edgehog.Containers.Container.Deployment.Changes.DeployImage do
  @moduledoc """
  Deploys or reuses an `Image.Deployment` for the container's image on the
  target device and relates `:image_deployment`.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    with true <- changeset.valid?,
         {:ok, container} <- Ash.Changeset.fetch_argument(changeset, :container),
         {:ok, device} <- Ash.Changeset.fetch_argument(changeset, :device),
         {:ok, container} <- Ash.load(container, [:image], tenant: tenant) do
      input = %{
        image_id: container.image.id,
        device_id: device.id,
        image: container.image,
        device: device
      }

      Ash.Changeset.manage_relationship(changeset, :image_deployment, input,
        on_no_match: {:create, :deploy},
        on_match: :ignore,
        on_lookup: :relate,
        use_identities: [:image_instance]
      )
    else
      {:error, error} -> Ash.Changeset.add_error(changeset, error)
      _ -> changeset
    end
  end
end
