#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule EdgehogWeb.GraphqlCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Mox
      import EdgehogWeb.GraphqlCase
    end
  end

  alias Ecto.Adapters.SQL

  import Mox

  setup :verify_on_exit!

  setup tags do
    pid = SQL.Sandbox.start_owner!(Edgehog.Repo, shared: not tags[:async])
    on_exit(fn -> SQL.Sandbox.stop_owner(pid) end)

    %{tenant: Edgehog.TenantsFixtures.tenant_fixture()}
  end

  def add_upload(context, _upload_name, nil), do: context

  def add_upload(context, upload_name, upload) do
    upload_path = [:__absinthe_plug__, :uploads]

    upload_map =
      (get_in(context, upload_path) || %{})
      |> Map.put(upload_name, upload)

    put_in(context, Enum.map(upload_path, &Access.key(&1, %{})), upload_map)
  end
end
