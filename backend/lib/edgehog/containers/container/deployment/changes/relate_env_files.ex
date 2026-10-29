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

defmodule Edgehog.Containers.Container.Deployment.Changes.RelateEnvFiles do
  @moduledoc """
  Attaches the target `:device_id` to each entry in the `:env_files` argument
  and relates them to the container deployment via `manage_relationship/4`.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    with true <- changeset.valid?,
         {:ok, device} <- Ash.Changeset.fetch_argument(changeset, :device) do
      env_files = Ash.Changeset.get_argument(changeset, :env_files) || []
      env_files_input = Enum.map(env_files, &Map.put(&1, :device_id, device.id))

      Ash.Changeset.manage_relationship(changeset, :env_files, env_files_input,
        on_no_match: :create,
        on_match: :ignore,
        on_lookup: :ignore
      )
    else
      _ -> changeset
    end
  end
end
