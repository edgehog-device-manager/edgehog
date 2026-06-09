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

defmodule Edgehog.Tenants.Tenant.Changes.StartReconciliation do
  @moduledoc """
  Reconciliation starter.

  On a new tenant creation this change starts the delivery policy, interface and
  triggers reconciliation.
  """
  use Ash.Resource.Change

  alias Edgehog.Tenants.Reconciler

  require Logger

  @test Mix.env() == :test
  @mode if @test, do: :manual, else: :auto

  @impl Ash.Resource.Change
  def change(changeset, _opts, _ctx) do
    Ash.Changeset.after_transaction(changeset, &start_reconciler/2)
  end

  defp start_reconciler(_changeset, {:ok, tenant}) do
    Reconciler.start_reconciler(tenant, mode: @mode)

    {:ok, tenant}
  end

  defp start_reconciler(_changeset, {:error, error}) do
    warn_message = """
    Seems like it was not possible to create the tenant:

    #{inspect(error)}

    Is the database ok?
    """

    Logger.warning(warn_message)

    {:error, error}
  end
end
