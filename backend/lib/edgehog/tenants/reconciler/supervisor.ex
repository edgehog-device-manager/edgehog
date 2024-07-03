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

defmodule Edgehog.Tenants.Reconciler.Supervisor do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(opts) do
    reconciler_args =
      reconciler_base_args()
      |> Keyword.put(:tenant_to_trigger_url_fun, Keyword.fetch!(opts, :tenant_to_trigger_url_fun))

    children = [
      {Task.Supervisor, name: Edgehog.Tenants.Reconciler.TaskSupervisor},
      {Edgehog.Tenants.Reconciler, reconciler_args}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  # Pass additional executor-specific test args only in the test env
  if Mix.env() == :test do
    defp reconciler_base_args, do: [mode: :manual]
  else
    defp reconciler_base_args, do: []
  end
end
