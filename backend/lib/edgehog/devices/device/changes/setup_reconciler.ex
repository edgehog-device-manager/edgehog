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

defmodule Edgehog.Devices.Device.Changes.SetupReconciler do
  @moduledoc """
  Sets up the reconciler on connection events.
  """

  use Ash.Resource.Change

  alias Edgehog.Containers.Reconciler

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      maybe_start_reconciler(result)
      result
    end)
  end

  defp maybe_start_reconciler({:ok, device}) do
    device = Ash.load!(device, :tenant)
    tenant = device.tenant

    Reconciler.register_device(device, tenant)
  end

  defp maybe_start_reconciler(other), do: other
end
