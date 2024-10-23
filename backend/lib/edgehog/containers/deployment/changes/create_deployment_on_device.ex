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

defmodule Edgehog.Containers.Deployment.Changes.CreateDeploymentOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers.Deployment.Executor

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      start_deployment(result, tenant)
    end)
  end

  defp start_deployment({:ok, deployment}, tenant) do
    opts = %{tenant: tenant, deployment: deployment}
    Executor.start(opts)

    {:ok, deployment}
  end
end
