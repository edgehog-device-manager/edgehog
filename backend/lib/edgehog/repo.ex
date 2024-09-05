#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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
  use AshPostgres.Repo, otp_app: :edgehog

  require Ecto.Query

  def installed_extensions do
    ["ash-functions"]
  end

  def min_pg_version do
    %Version{major: 13, minor: 0, patch: 0}
  end

  def fetch(queryable, id, opts \\ []) do
    {error, opts} = Keyword.pop_first(opts, :error, :not_found)

    case get(queryable, id, opts) do
      nil -> {:error, error}
      item -> {:ok, item}
    end
  end

  def fetch_by(queryable, clauses, opts \\ []) do
    {error, opts} = Keyword.pop_first(opts, :error, :not_found)

    case get_by(queryable, clauses, opts) do
      nil -> {:error, error}
      item -> {:ok, item}
    end
  end

  def transact(fun, opts \\ []) do
    transaction(
      fn ->
        case fun.() do
          {:ok, value} -> value
          :ok -> :transaction_committed
          {:error, reason} -> rollback(reason)
          :error -> rollback(:transaction_rollback_error)
        end
      end,
      opts
    )
  end
end
