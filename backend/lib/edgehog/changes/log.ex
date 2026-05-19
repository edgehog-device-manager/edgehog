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

defmodule Edgehog.Changes.Log do
  @moduledoc """
  An Ash.Resource.Change that emits a log.

  ## Options

  - `:message`          ::  The message to log. Required for all modes except `:after_transaction`.
  - `:log_level`        :: The Logger level to use (e.g., `:info`, `:debug`, `:warning`). Defaults to `:info`.
  - `:log_meta`         :: Custom metadata to pass to the Logger. Defaults to `[]`.

  ## Behavior

  The change hooks into the `Ash.Changeset` lifecycle based on the configured `:mode`. 

  ### Metadata Injection

  Regardless of your custom `:log_meta` settings, this change automatically injects the following contextual keys into the Logger metadata if they are available:
  * `:tenant` (Extracts the `slug` if an `Edgehog.Tenants.Tenant` struct is present in the context)
  * `:resource`
  * `:action` (Defaults to `:unknown` if not resolved)
  * `:error` (Only injected during failed `:after_transaction` hooks)

  ## Example

      change {Edgehog.Changes.Log,
        message: "Device created successfully", 
        log_level: :info}
  """

  use Ash.Resource.Change

  require Logger

  @message :message
  @log_meta :log_meta
  @log_level :log_level

  @required [@message]

  @impl Ash.Resource.Change
  def init(opts) do
    {_, errors} = Enum.reduce(@required, {opts, []}, &error_if_not_present/2)

    if Enum.empty?(errors),
      do: {:ok, set_defaults(opts)},
      else: {:error, errors}
  end

  @impl Ash.Resource.Change
  def change(%{valid: false} = changeset, _opts, _context) do
    changeset
  end

  @impl Ash.Resource.Change
  def change(changeset, opts, context) do
    # Put tenant in the logger options, if not already present
    opts = curry_log_metadata(opts, changeset, context)

    log(opts)

    changeset
  end

  @impl Ash.Resource.Change
  def atomic(%{valid: false}, _opts, _context) do
    :ok
  end

  @impl Ash.Resource.Change
  def atomic(changeset, opts, context) do
    # Put tenant in the logger options, if not already present
    opts = curry_log_metadata(opts, changeset, context)

    log(opts)

    :ok
  end

  defp curry_log_metadata(opts, changeset, context) do
    %{tenant: tenant} = context
    %{action: action, resource: resource} = changeset

    # Tenant might be the tenant or the tenant_id, always use the tenant id
    tenant =
      with %Edgehog.Tenants.Tenant{tenant_id: id} <- tenant,
           do: id

    action = Map.get(action, :name, :unknown)

    log_meta =
      opts
      |> Keyword.get(@log_meta, [])
      |> Keyword.put_new(:tenant_id, tenant)
      |> Keyword.put_new(:resource, resource)
      |> Keyword.put_new(:action, action)

    Keyword.put(opts, @log_meta, log_meta)
  end

  defp set_defaults(opts) do
    opts
    |> Keyword.put_new(@log_meta, [])
    |> Keyword.put_new(@log_level, :info)
  end

  # Before action / transaction
  defp log(opts) do
    Logger.log(opts[@log_level], opts[@message], opts[@log_meta])
  end

  defp error_if_not_present(key, {opts, errors}) do
    error = "Missing key #{inspect(key)}."

    if Keyword.has_key?(opts, key),
      do: {opts, errors},
      else: {opts, [error | errors]}
  end
end
