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

defmodule Edgehog.Containers.Deployment.ManualActions.StartSupervisor do
  @moduledoc """
  Manual action to start a deployment supervisor without the need for a database transaction.
  """

  use Ash.Resource.ManualUpdate

  alias Edgehog.Containers.Deployment.Orchestrator

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, %{tenant: tenant}) do
    deployment = changeset.data

    with {:ok, _pid} <- Orchestrator.conduct(deployment, tenant) do
      {:ok, deployment}
    end
  end
end
