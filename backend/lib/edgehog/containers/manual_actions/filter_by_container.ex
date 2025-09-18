#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Containers.ManualActions.FilterByContainer do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Edgehog.Containers

  @impl Ash.Resource.ManualRead
  def read(query, _data_layer_query, _opts, context) do
    %{tenant: tenant} = context

    with {:ok, container_id} <- Ash.Query.fetch_argument(query, :container_id),
         {:ok, relations} <-
           Containers.releases_with_container(container_id, tenant: tenant, load: :release) do
      {:ok, Enum.map(relations, & &1.release)}
    end
  end
end
