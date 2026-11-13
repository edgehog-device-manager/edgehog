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

defmodule Edgehog.Audit.AuditService do
  @moduledoc """
  Service module exposing the API to audit events across the application.
  """

  alias Edgehog.Audit.Event
  alias Edgehog.Audit.Types.ActionEventInfo
  alias Edgehog.Config
  alias Edgehog.Tenants.Tenant

  require Logger

  @type option :: {:tenant, Tenant.t() | integer() | nil}

  @type convenience_option ::
          option()
          | {:metadata, map()}
          | {:ash_action_info, ActionEventInfo.t() | nil}

  @doc """
  Registers an event by logging the given message and creating an `Edgehog.Audit.Event`
  resource, if configured.
  """
  @spec register_event(
          message :: String.t(),
          log_level :: Logger.level(),
          ash_action_info :: ActionEventInfo.t() | nil,
          metadata :: map(),
          opts :: [option()]
        ) :: :ok | {:error, term()}
  def register_event(
        message,
        log_level,
        ash_action_info \\ nil,
        metadata \\ %{},
        opts \\ []
      ) do
    tenant = Keyword.get(opts, :tenant)

    maybe_log_event(message, log_level, ash_action_info, metadata, tenant)
    maybe_store_event(message, log_level, ash_action_info, metadata, tenant)
  end

  @doc "Registers an audit event at debug level."
  @spec debug(String.t(), [convenience_option()]) :: :ok | {:error, term()}
  def debug(message, opts \\ []), do: register_with_level(message, :debug, opts)

  @doc "Registers an audit event at info level."
  @spec info(String.t(), [convenience_option()]) :: :ok | {:error, term()}
  def info(message, opts \\ []), do: register_with_level(message, :info, opts)

  @doc "Registers an audit event at warning level."
  @spec warning(String.t(), [convenience_option()]) :: :ok | {:error, term()}
  def warning(message, opts \\ []), do: register_with_level(message, :warning, opts)

  @doc "Registers an audit event at error level."
  @spec error(String.t(), [convenience_option()]) :: :ok | {:error, term()}
  def error(message, opts \\ []), do: register_with_level(message, :error, opts)

  defp register_with_level(message, level, opts) do
    ash_action_info = Keyword.get(opts, :ash_action_info)
    metadata = Keyword.get(opts, :metadata, %{})

    register_event(
      message,
      level,
      ash_action_info,
      metadata,
      Keyword.take(opts, [:tenant])
    )
  end

  defp maybe_log_event(message, log_level, ash_action_info, metadata, tenant) do
    if Config.audit_log_events?() do
      log_metadata =
        metadata
        |> Keyword.new()
        |> maybe_put_ash_action_info(ash_action_info)
        |> maybe_put_tenant(tenant)

      Logger.log(log_level, message, log_metadata)
    end

    :ok
  end

  defp maybe_put_ash_action_info(keyword, nil), do: keyword

  defp maybe_put_ash_action_info(keyword, ash_action_info),
    do: Keyword.put(keyword, :ash_action_info, ash_action_info)

  defp maybe_put_tenant(keyword, nil), do: keyword

  defp maybe_put_tenant(keyword, %Tenant{slug: slug}),
    do: Keyword.put(keyword, :tenant, slug)

  defp maybe_put_tenant(keyword, tenant_id),
    do: Keyword.put(keyword, :tenant, tenant_id)

  defp maybe_store_event(message, log_level, ash_action_info, metadata, tenant) do
    if Config.audit_store_events?() do
      attrs = %{
        message: message,
        log_level: log_level,
        ash_action_info: ash_action_info,
        metadata: metadata
      }

      case Event
           |> Ash.Changeset.for_create(:create, attrs, tenant: tenant)
           |> Ash.create() do
        {:ok, _event} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :ok
    end
  end
end
