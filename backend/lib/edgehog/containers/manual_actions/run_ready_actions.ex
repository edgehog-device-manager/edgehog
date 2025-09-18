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

defmodule Edgehog.Containers.ManualActions.RunReadyActions do
  @moduledoc false

  use Ash.Resource.ManualUpdate

  alias Edgehog.Containers

  require Ash.Query
  require Logger

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    deployment = changeset.data

    with {:ok, deployment} <- Ash.load(deployment, :ready_actions) do
      ready_actions_results = Enum.map(deployment.ready_actions, &Containers.run_ready_action/1)

      for {status, result} <- ready_actions_results, status == :error do
        Logger.error("Error running ready action for deployment #{deployment.id}: #{inspect(result)}")
      end

      {:ok, deployment}
    end
  end
end
