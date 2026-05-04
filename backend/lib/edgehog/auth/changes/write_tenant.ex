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

defmodule Edgehog.Auth.Changes.WriteTenant do
  @moduledoc """
  Generic tuple writer. 
  """

  use Ash.Resource.Change

  alias Edgehog.Auth.FGAService

  require Logger

  @impl Ash.Resource.Change
  def init(opts) do
    errors =
      if Keyword.has_key?(opts, :obj),
        do: [],
        else: [:obj_missing]

    errors =
      if Keyword.has_key?(opts, :obj_id),
        do: errors,
        else: [:obj_id_missing | errors]

    if Enum.empty?(errors),
      do: {:ok, opts},
      else: {:error, errors}
  end

  @impl Ash.Resource.Change
  def change(changeset, opts, context) do
    Ash.Changeset.after_transaction(changeset, &write_tenant_tuple(&1, &2, opts, context))
  end

  defp write_tenant_tuple(_changeset, {:ok, result}, opts, %{tenant: tenant}) do
    # Writes the tuple
    # {"tenant:slug", "tenant", "obj:obj_id"}

    obj =
      opts
      |> Keyword.fetch!(:obj)
      |> to_string()

    obj_id = opts[:obj_id]

    obj_id =
      result
      |> Ash.load!(obj_id)
      |> Map.get(obj_id)
      |> to_string()

    obj = "#{obj}:#{obj_id}"

    rel = "tenant"

    slug = tenant.slug
    subj = "tenant:#{slug}"

    with {:ok, _res} <- FGAService.write(subj, rel, obj) do
      {:ok, result}
    end
  end

  defp write_tenant_tuple(_changeset, error, opts, context) do
    Logger.debug("Error while executing DB transaction. Skipping writing tuple on the provider.",
      error: error,
      opts: opts,
      context: context
    )

    error
  end
end
