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

defmodule Edgehog.Containers.Deployment.Changes.Reconcile do
  @moduledoc """
  Starts a reconciliation with the device.

  Careful: this implies querying appengine, it can be traffic intensive.
  """
  use Ash.Resource.Change

  alias Edgehog.Containers.Reconciler

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    deployment = Ash.load!(changeset.data, :device, tenant: tenant)
    device = deployment.device
    device_id = device.id

    Ash.Changeset.after_transaction(changeset, &after_transaction(&1, &2, device_id, tenant))
  end

  defp after_transaction(_changeset, {:ok, _resource} = result, device_id, tenant) do
    args = %{device_id: device_id, tenant: tenant}

    Reconciler.Core.reconcile(args)

    result
  end

  defp after_transaction(_changeset, result, _device_id, _tenant), do: result
end
