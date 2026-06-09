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

defmodule Edgehog.Tenants.Reconciler.Context do
  @moduledoc """
  Helper function for tenant reconciliation.

  The functions below let core modules interact with the context: adding,
  changing keys, adding errors, checking the presence of errors, etc.

  The context is a map. keys can be arbitrarily added and fetched, however, some keys are present by default:

  - tenant                  :: the given tenant, for which we're building the context
  - realm_management_client :: the realm management client to interact with astarte
  - astarte_version         :: the astarte version
  - errors                  :: a Keyword list of errors, scoped per reconciler section (delivery policies, triggers, interfaces)
  """

  alias Astarte.Client.RealmManagement

  @doc """
  Builds a context, given a tenant.

  This will only provide the initial context. A context is a map. Keys can be added as you go, but some keys are provided here:

  - tenant                  :: the given tenant, for which we're building the context
  - realm_management_client :: the realm management client to interact with astarte
  - astarte_version         :: the astarte version
  - errors                  :: a Keyword list of errors, scoped per reconciler section (delivery policies, triggers, interfaces). The list is empty by default

  ```elixir
  %{
    tenant: tenant,
    rm_client: realm_management_client,
    astarte_version: astarte_version,
    errors: []
  }
  ```

  You might want to match on the following possible return values

  - `{:ok, context}`                       :: The context was successfully iniyialized.
  - `{:error, :missing_rm_client}`         :: The realm management client was not correctly initialized. Possibly as misconfiguration of the astarte realm.
  - `{:error, :invalid_tenant}`            :: The provided tenant was not valid.
  - `{:error, %Astarte.Client.APIError{}}` :: There was a communication error with astarte.
  """
  def build(%Edgehog.Tenants.Tenant{} = tenant) do
    # Crash if not configured. It's configured in `application.ex` itself.
    trigger_fun = Application.fetch_env!(:edgehog, :tenant_to_trigger_url_fun)

    tenant = Ash.load!(tenant, [realm: [:realm_management_client]], tenant: tenant)

    rm_client =
      tenant
      |> Map.get(:realm, %{})
      |> Map.get(:realm_management_client)

    rm_client =
      case rm_client do
        nil -> {:error, :missing_rm_client}
        rm_client -> {:ok, rm_client}
      end

    with {:ok, rm_client} <- rm_client,
         {:ok, version} <- astarte_version(rm_client) do
      ctx = %{
        tenant: tenant,
        rm_client: rm_client,
        astarte_version: version,
        tenant_to_trigger_url_fun: trigger_fun,
        errors: []
      }

      {:ok, ctx}
    end
  end

  def build(_tenant) do
    {:error, :invalid_tenant}
  end

  defp astarte_version(rm_client) do
    with {:ok, %{"data" => version}} <- RealmManagement.Version.get(rm_client) do
      {:ok, version}
    end
  end

  @doc """
  Adds a key to the context.

  Example:

  ```elixir
  add_context(context, delivery_policies_compatible: false)
  ```
  """
  def add_context(context, opts \\ []) do
    opts = Enum.into(opts, %{})
    Map.merge(context, opts)
  end

  @doc """
  Retrieves a key from the context, defaulting to a default value if not present:

  Example: 

  ```elixir
  get_context(context, :delivery_policies_compatible, true)
  ```
  """
  def get_context(context, key, default \\ nil) do
    Map.get(context, key, default)
  end

  @doc """
  Adds an error to the context, in the corresponding section

  Sections are handled as keys in a keyword list (the errors in the context):

  ```elixir
  %{
    errors: [
      delivery_policies: [
        error1,
        error2,
        error3,
        ...
      ]
    ]
  }
  ```
  """
  def add_error(context, section, error) do
    %{errors: ctx_errors} = context

    errors = Keyword.get(ctx_errors, section, [])
    errors = [error | errors]

    ctx_errors = Keyword.put(ctx_errors, section, errors)

    Map.put(context, :errors, ctx_errors)
  end

  @doc """
  Checks whether there are errors or a specific section has errors.

  ## Examples:

  ```elixir
  > context = %{errors: []}
  %{errors: []}

  > Context.errors?(context)
  false
  ```

  ```elixir
  > context = %{errors: [sec_1: [:some_error]]}
  %{errors: [sec_1: [:some_error]]}

  > Context.errors?(context, :sec_1)
  true

  > Context.errors?(context, :sec_2)
  false

  > Context.errors?(context)
  true
  ```
  """
  def errors?(context, section \\ nil) do
    errors = Map.get(context, :errors, [])

    errors =
      if section,
        do: Keyword.get(errors, section, []),
        else: errors

    not Enum.empty?(errors)
  end
end
