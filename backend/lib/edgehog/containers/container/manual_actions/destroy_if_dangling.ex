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

    dangling? =
      case Ash.load(container, :dangling?, tenant: tenant) do
        {:ok, container} -> container.dangling?
        _ -> false
      end

    if dangling?,
      do: delete_container(container, tenant),
      else: {:ok, container}
  end

  defp delete_container(container, tenant) do
    changeset = Ash.Changeset.for_destroy(container, :destroy)

    changeset =
      case Ash.load(container, :image) do
        {:ok, container} ->
          image = container.image

          Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
            maybe_cleanup(result, image, tenant)
          end)

        _ ->
          changeset
      end

    with :ok <- Ash.destroy(changeset, tenant: tenant) do
      {:ok, container}
    end
  end

  defp maybe_cleanup({:ok, _} = result, image, tenant) do
    Containers.destroy_image_if_dangling(image, tenant: tenant)
    result
  end

  defp maybe_cleanup(result, _image, _tenant), do: result
end
