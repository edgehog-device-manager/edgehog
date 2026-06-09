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

defmodule Edgehog.Tenants.Reconciler.Core.Interfaces do
  @moduledoc """
  The interfaces part of the reconciler core.
  """

  alias Edgehog.Astarte.Interface
  alias Edgehog.Tenants.Reconciler.AstarteResources
  alias Edgehog.Tenants.Reconciler.Context

  require Logger

  @interfaces AstarteResources.load_interfaces()
  @error_section :interfaces

  def list_interfaces do
    @interfaces
  end

  def reconcile(context) do
    context
    |> maybe_warn_user()
    |> reconcile_interfaces()
  end

  defp maybe_warn_user(%{errors: []} = context), do: context

  defp maybe_warn_user(context) do
    warning_log = """
    Some errors spot in the given context for interfaces reconciliation.
    Perhaps trigger delivery policy reconciliation failed?

    Installing interfaces anyways.
    """

    Logger.warning(warning_log)

    context
  end

  defp reconcile_interfaces(context) do
    %{tenant: %{slug: slug}} = context
    Logger.info("Reconciling interfaces for tenant #{slug}.")

    reduction = Enum.reduce_while(list_interfaces(), context, &reducer/2)

    with {:error, error} <- reduction do
      Context.add_error(context, @error_section, error)
    end
  end

  defp reducer(interface, context) do
    case reconcile_interface(context, interface) do
      {:error, error} -> {:halt, {:error, error}}
      context -> {:cont, context}
    end
  end

  def reconcile_interface(context, interface) do
    %{rm_client: rm_client} = context

    %{
      "interface_name" => interface_name,
      "version_major" => major
    } = interface

    existing_interface = Interface.fetch_by_name_and_major(rm_client, interface_name, major)

    update_or_install(context, interface, existing_interface)
  end

  # ===================== Update or install

  defp update_or_install(context, interface, {:ok, old_interface}) do
    %{
      "version_major" => major,
      "version_minor" => minor
    } = interface

    %{
      "version_major" => old_major,
      "version_minor" => old_minor
    } = old_interface

    cond do
      old_major != major -> major_difference(context, interface, old_interface)
      minor > old_minor -> update(context, interface)
      # The major is the same and the old minor >= minor... It's a noop ! :)
      true -> context
    end
  end

  defp update_or_install(context, interface, {:error, :not_found}) do
    # The old interface was not found. Install it !
    install(context, interface)
  end

  defp update_or_install(context, interface, error) do
    %{tenant: %{slug: slug}} = context
    %{"interface_name" => name} = interface

    error = """
    Error while installing interface #{name} for tenant #{slug}

    #{inspect(error)}
    """

    Logger.error(error)

    Context.add_error(context, @error_section, error)
  end

  # ===================== Update

  defp update(context, interface) do
    %{rm_client: rm_client} = context

    %{
      "interface_name" => name,
      "version_major" => major
    } = interface

    %{tenant: tenant} = context
    id = tenant.tenant_id

    case Interface.update(rm_client, name, major, interface) do
      :ok ->
        context

      {:error, error} ->
        log_error = """
        Error while updating an interface.

        - name: #{name}
        - major: #{major}
        - tenant: #{id}

        #{inspect(error)}

        Is the connection with astarte working?
        """

        Logger.error(log_error)

        Context.add_error(context, @error_section, error)
    end
  end

  # ===================== Install

  defp install(context, interface) do
    %{rm_client: rm_client} = context

    %{
      "interface_name" => name,
      "version_major" => major
    } = interface

    %{tenant: tenant} = context
    id = tenant.tenant_id

    case Interface.create(rm_client, interface) do
      :ok ->
        context

      {:error, error} ->
        log_error = """
        Error while installing an interface.

        - name: #{name}
        - major: #{major}
        - tenant: #{id}

        #{inspect(error)}

        Is the connection with astarte working?
        """

        Logger.error(log_error)

        Context.add_error(context, @error_section, error)
    end
  end

  defp major_difference(_context, interface, old_interface) do
    %{
      "interface_name" => name,
      "version_major" => major
    } = interface

    %{"version_major" => old_major} = old_interface

    log_error = """
    Error while retrieving interface #{name}.

    Requested version #{major} but got #{old_major}.

    Perhaps a bug in Astarte?

    This is not really recoverable, bubbling the error up.
    """

    error = :astarte_interface_major_mismatch

    Logger.error(log_error)

    {:error, error}
  end
end
