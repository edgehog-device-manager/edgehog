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

defmodule Edgehog.Mocks.Tenants.Reconciler do
  @behaviour Edgehog.Tenants.Reconciler.Behaviour

  alias Edgehog.Tenants.Tenant

  @impl true
  def reconcile_tenant(%Tenant{} = _tenant), do: :ok

  @impl true
  def cleanup_tenant(%Tenant{} = _tenant), do: :ok
end
