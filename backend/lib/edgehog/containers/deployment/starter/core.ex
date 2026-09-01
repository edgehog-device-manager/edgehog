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

defmodule Edgehog.Containers.Deployment.Starter.Core do
  @moduledoc """
  Deployment starter core functions.

  This is a collection of pure functions that handle the business logic. They
  primarily are functions that interact with other parts of the application
  (e.g., read the database, send signals, subscribe to events, etc.).
  """

  alias Edgehog.Containers.Deployment

  require Ash.Query
  require Logger

  @doc """
  Loads pending deployments into the state.

  given a device and a tenant scope returns the list of deployments `:pending`
  for that device and tenant.

  Example:
  ```elixir
  > device = %Device{device_id: "some-device-id"}
  > tenant = %Tenant{}

  > Core.load(device, tenant)
  [
    %Deployment{},
    %Deployment{},
    ...
  ]
  ```
  """
  def load(device, tenant) do
    device_id = device.id

    Deployment
    |> Ash.Query.filter(state: :pending)
    |> Ash.Query.filter(device_id: device_id)
    |> Ash.read(tenant: tenant)
  end

  @doc """
  Starts all given deployment. For each deployment the orchestrator will be called.

  returns the list of errors generated while starting each deployment in the shape
  `{:error, error, deployment}`.
  """
  def start(deployments, tenant) do
    Enum.reduce(deployments, [], &start_deployment(&1, tenant, &2))
  end

  defp start_deployment(deployment, tenant, errors) do
    case Deployment.Orchestrator.conduct(deployment, tenant) do
      {:ok, _pid} -> errors
      {:error, error} -> [{:error, error, deployment} | errors]
    end
  end

  @doc """
  Logs all the errors given as first argument. The errors must follow the
  `{:error, error, deployment}` convention, so that it's understandable for which
  deployment the error was generated.
  """

  # Logging functions

  def log_start_completed(device_id) do
    Logger.info("""
    Successfully started provisioning of all pending deployments on device #{device_id}
    """)
  end

  def log_start_errors(device) do
    Logger.warning("""
    It was not possible to start all the deployments for the device #{device.device_id}. Further details will be logged.
    """)
  end

  def log_errors(errors, device) do
    Enum.each(errors, &log_error(&1, device))
  end

  def log_start_unexpected_error(device_id, error) do
    Logger.error("""
    Unexpected error while starting deployments for device #{device_id}: #{inspect(error)}. Shutting down the starter.
    """)
  end

  def log_start_terminated(device_id, reason) do
    Logger.debug("""
    Terminating deployments starter server for device #{device_id} with reason #{inspect(reason)}.
    """)
  end

  defp log_error({:error, error, deployment}, device) do
    Logger.error("""
    Error while starting deployment #{deployment.id} on device #{device.device_id}: #{inspect(error)}
    """)
  end
end
