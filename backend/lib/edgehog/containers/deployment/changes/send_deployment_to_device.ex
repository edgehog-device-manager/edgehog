# This file is part of Edgehog.
#
# Copyright 2025-2026 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment.Changes.SendDeploymentToDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers.Deployment.Supervisor

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    Ash.Changeset.after_transaction(changeset, &after_transaction(&1, &2, tenant))
  end

  defp after_transaction(_changeset, {:ok, deployment}, tenant) do
    Supervisor.supervise(deployment, tenant)

    {:ok, deployment}
  end

  defp after_transaction(_changeset, error, _tenant), do: error
end
