#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.Repo do
  use Ecto.Repo,
    otp_app: :edgehog,
    adapter: Ecto.Adapters.Postgres

  require Ecto.Query

  @tenant_key {__MODULE__, :tenant_id}

  def put_tenant_id(tenant_id) do
    Process.put(@tenant_key, tenant_id)
  end

  def get_tenant_id do
    Process.get(@tenant_key)
  end

  def fetch(queryable, id, opts \\ []) do
    empty = Keyword.get(opts, :empty_return, :not_found)

    case get(queryable, id, opts) do
      nil -> {:error, empty}
      item -> {:ok, item}
    end
  end

  def fetch_by(queryable, clauses, opts \\ []) do
    empty = Keyword.get(opts, :empty_return, :not_found)

    case get_by(queryable, clauses, opts) do
      nil -> {:error, empty}
      item -> {:ok, item}
    end
  end

  @impl true
  def prepare_query(_operation, query, opts) do
    cond do
      opts[:skip_tenant_id] || opts[:schema_migration] ->
        {query, opts}

      tenant_id = opts[:tenant_id] ->
        {Ecto.Query.where(query, tenant_id: ^tenant_id), opts}

      true ->
        raise "expected tenant_id or skip_tenant_id to be set"
    end
  end

  @impl true
  def default_options(_operation) do
    [tenant_id: get_tenant_id()]
  end
end
