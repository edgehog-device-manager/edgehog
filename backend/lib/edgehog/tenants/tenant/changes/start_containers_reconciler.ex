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

defmodule Edgehog.Tenants.Tenant.Changes.StartContainersReconciler do
  @moduledoc """
  Starts the container reconciler for the current tenant.
  """

  use Ash.Resource.Change

  alias Edgehog.Containers.Reconciler

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, tenant} <- result do
        start_reconciler(tenant)
      end

      result
    end)
  end

  defp start_reconciler(tenant) do
    Reconciler.start_link(tenant: tenant)
  end
end
