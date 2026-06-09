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

defmodule Edgehog.Tenants.Reconciler.Core do
  @moduledoc """
  Tenants reconciler module.

  This module provides the core functionality of the reconciler, such as list
  all delivery policies, build and install triggers, install interfaces etc.

  The main function is `reconcile/1`.

  `reconcile/1` takes a valid tenant and reconciles it as follows:

  1. checks the astarte version. This impacts what can and cannot be installed:
     + version >= 1.1.1      => astarte supports trigger delivery policies.
     + version >= 1.3.0-rc.0 => astarte supports device registration and device deletion triggers
  2. installs trigger delivery policies (if the astarte version supports it)
  3. installs astarte interfaces
  4. installs triggers (if supported and with delivery policies if supported)
  """

  alias Edgehog.Tenants.Reconciler.Context
  alias Edgehog.Tenants.Reconciler.Core

  require Logger

  def reconcile(tenant) do
    context = Context.build(tenant)

    with {:ok, context} <- context do
      context
      |> Core.DeliveryPolicies.reconcile()
      |> Core.Interfaces.reconcile()
      |> Core.Triggers.reconcile()
      |> parse_final_context()
    end
  end

  defp parse_final_context(context) do
    if Context.errors?(context) do
      log_warn = """
      The reconciliation context contains errors. Check the above logs to understand what happened and debug your instance !
      """

      Logger.warning(log_warn)
    end

    :ok
  end
end
