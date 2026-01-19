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

defmodule Edgehog.Astarte.DeviceFetcher.Supervisor do
  @moduledoc false
  use Supervisor

  alias Edgehog.Astarte
  alias Edgehog.Astarte.DeviceFetcher.Core
  alias Edgehog.Tenants

  require Logger

  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(opts) do
    opts = List.wrap(opts)

    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: Keyword.get(opts, :restart, :transient),
      shutdown: 500
    }
  end

  # Start Supervisor
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      {Task,
       fn ->
         Logger.info("Starting Astarte device states fetch...")
         fetch_and_store_devices()
         Logger.info("Astarte device states fetch completed.")
       end}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp fetch_and_store_devices do
    tenants = Tenants.fetch_all!()

    Enum.each(tenants, fn tenant ->
      realms = Astarte.fetch_realms!(tenant: tenant)

      Enum.each(realms, fn realm ->
        Core.fetch_device_from_astarte(realm, tenant)
      end)
    end)
  end
end
