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

defmodule Edgehog.Containers.ManualActions.DestroyIfDangling do
  @moduledoc """
  Is the given resource dangling (`dangling?` calculation returns true)? -> delete it!
  """

  use Ash.Resource.ManualDestroy

  @impl Ash.Resource.ManualDestroy
  def destroy(changeset, _opts, %{tenant: tenant}) do
    resource = changeset.data

    with {:ok, resource} <- Ash.load(resource, :dangling?) do
      if resource.dangling? do
        with :ok <- Ash.destroy(resource, tenant: tenant) do
          {:ok, resource}
        end
      else
        {:error, :not_dangling}
      end
    end
  end
end
