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
  An Ash.Resource.Change that emits a log entry at a specified hook lifecycle.

  ## Options

  - `:mode`             :: (Required) Determines *when* to emit the log. 
    Supported modes match the underlying `Ash.Changeset` lifecycle hooks:
    + `:before_action`
    + `:before_transaction`
    + `:after_action`
    + `:after_transaction`
  - `:message`          ::  The message to log. Required for all modes except `:after_transaction`.
  - `:message_success`  :: The message to log if a transaction succeeds. Required for `:after_transaction` mode.
  - `:message_fail`     :: The message to log if a transaction fails. Required for `:after_transaction` mode.
  - `:log_level`        :: The Logger level to use (e.g., `:info`, `:debug`, `:warning`). Defaults to `:info`.
  - `:log_meta`         :: Custom metadata to pass to the Logger. Defaults to `[]`.

  ## Behavior

  The change hooks into the `Ash.Changeset` lifecycle based on the configured `:mode`. 

  ### Metadata Injection

  Regardless of your custom `:log_meta` settings, this change automatically injects the following contextual keys into the Logger metadata if they are available:
  * `:tenant` (Extracts the `slug` if an `Edgehog.Tenants.Tenant` struct is present in the context)
  * `:domain`
  * `:resource`
  * `:action` (Defaults to `:unknown` if not resolved)
  * `:error` (Only injected during failed `:after_transaction` hooks)

  ### Message Resolution
  * `:before_action`, `:before_transaction`, and `:after_action` hooks exclusively evaluate the `:message` option.
  * `:after_transaction` evaluates either `:message_success` or `:message_fail` depending on the outcome of the transaction.

  ## Example

      change {Edgehog.Changes.Log, mode: :before_action, message: "Creating a new device..."}
      
      change {Edgehog.Changes.Log, 
        mode: :after_transaction, 
        message_success: "Device created successfully", 
        message_fail: "Failed to create device",
        log_level: :error}
  """

  use Ash.Resource.Change

  require Logger

  @mode :mode
  @message :message
  @message_success :message_success
  @message_fail :message_fail
  @log_meta :log_meta
  @log_level :log_level

  @required [@message]
  @required_after_transaction [@message_success, @message_fail]

  @impl Ash.Resource.Change
  def init(opts) do
    mode = Keyword.fetch!(opts, :mode)

    required =
      case mode do
        :after_transaction -> @required_after_transaction
        _ -> @required
      end

    {_, errors} = Enum.reduce(required, {opts, []}, &error_if_not_present/2)

    if Enum.empty?(errors),
      do: {:ok, set_defaults(opts)},
      else: {:error, errors}
  end

  @impl Ash.Resource.Change
  def change(changeset, opts, context) do
    do_change(changeset, opts, context)
  end

  @impl Ash.Resource.Change
  def atomic(changeset, opts, context) do
    {:ok, do_change(changeset, opts, context)}
  end

  defp do_change(changeset, opts, context) do
    mode = Keyword.fetch!(opts, @mode)

    # Put tenant in the logger options, if not already present
    opts = curry_log_metadata(opts, changeset, context)

    log_function =
      case mode do
        :after_action -> &log(opts, &1, &2)
        :after_transaction -> &log(opts, &1, &2)
        :before_action -> &log(opts, &1)
        :before_transaction -> &log(opts, &1)
      end

    m = Ash.Changeset
    f = mode
    a = [changeset, log_function]

    apply(m, f, a)
  end

  defp curry_log_metadata(opts, changeset, context) do
    %{tenant: tenant} = context
    %{action: action, resource: resource, domain: domain} = changeset

    tenant =
      with %Edgehog.Tenants.Tenant{slug: slug} <- tenant,
           do: slug

    action = Map.get(action, :name, :unknown)

    log_meta =
      opts
      |> Keyword.get(@log_meta, [])
      |> Keyword.put_new(:tenant, tenant)
      |> Keyword.put_new(:domain, domain)
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
  defp log(opts, changeset) do
    Logger.log(opts[@log_level], opts[@message], opts[@log_meta])

    changeset
  end

  # After transaction, success
  defp log(opts, _changeset, {:ok, _result} = data) do
    Logger.log(opts[@log_level], opts[@message_success], opts[@log_meta])

    data
  end

  # After transaction, fail
  defp log(opts, _changeset, {:error, error} = data) do
    # If failed with some error, possibly log it
    log_meta =
      opts
      |> Keyword.fetch!(@log_meta)
      |> Keyword.put_new(:error, error)

    Logger.log(opts[@log_level], opts[@message_fail], log_meta)

    data
  end

  # After action
  defp log(opts, _changeset, result) do
    Logger.log(opts[@log_level], opts[@message], opts[@log_meta])

    {:ok, result}
  end

  defp error_if_not_present(key, {opts, errors}) do
    error = "Missing key #{inspect(key)}."

    if Keyword.has_key?(opts, key),
      do: {opts, errors},
      else: {opts, [error | errors]}
  end
end
