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

defmodule Edgehog.Containers.Container.ManualActions.DestroyIfDangling do
  @moduledoc false

  use Ash.Resource.ManualDestroy

  alias Edgehog.Containers

  @impl Ash.Resource.ManualDestroy
  def destroy(changeset, _opts, context) do
    container = changeset.data
    %{tenant: tenant} = context

    with {:ok, container} <- Ash.load(container, :dangling?) do
      if container.dangling? do
        # Container is dangling, destroy it and trigger image cleanup
        image_id = container.image_id

        changeset
        |> Ash.Changeset.after_action(fn _changeset, destroyed_container ->
          # Try to destroy the image if it's also dangling
          _ = Containers.destroy_image_if_dangling(image_id, tenant: tenant)

          {:ok, destroyed_container}
        end)
        |> Ash.destroy()
      else
        # Container is not dangling, don't destroy it
        {:ok, container}
      end
    end
  end
end
