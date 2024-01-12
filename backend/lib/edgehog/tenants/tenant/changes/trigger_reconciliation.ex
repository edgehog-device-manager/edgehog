#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.Tenants.Tenant.Changes.TriggerReconciliation do
  use Ash.Resource.Change

  alias Edgehog.Tenants

  @impl true
  def change(changeset, _opts, _ctx) do
    Ash.Changeset.after_action(changeset, fn _changeset, tenant ->
      # TODO: this can probably be done with Ash notifiers, investigate that
      Tenants.Tenant.reconcile(tenant)

      {:ok, tenant}
    end)
  end
end
