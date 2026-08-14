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

defmodule Edgehog.Devices.Device.Changes.DeployPending do
  @moduledoc """
  After the transaction, deploy all deployments still marked as `:pending` for
  the given device.
  """
  use Ash.Resource.Change

  alias Edgehog.Containers.Deployment.Starter

  @cook_module Application.compile_env(:edgehog, :container_starter, Starter)

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, device} <- result,
           {:ok, _pid} <- @cook_module.cook(device, tenant) do
        {:ok, device}
      end
    end)
  end
end
