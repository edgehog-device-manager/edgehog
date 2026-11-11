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

defmodule Edgehog.Containers.Calculations.ResourceEvents do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation

  @resource_event_module Application.compile_env(
                           :edgehog,
                           :astarte_resource_event_module,
                           Edgehog.Astarte.Device.ResourceEvent
                         )

  @impl Calculation
  def load(_query, opts, _context) do
    Enum.uniq([:id, opts[:resource_id_key], device: [:device_id, :appengine_client]])
  end

  @impl Calculation
  def calculate(deployments, opts, _context) do
    interface = Keyword.fetch!(opts, :interface)
    resource_id_key = Keyword.fetch!(opts, :resource_id_key)
    event_type = Keyword.fetch!(opts, :event_type)
    limit = Keyword.get(opts, :limit)

    query = maybe_add_limit([], limit)

    Enum.map(deployments, fn deployment ->
      %{
        device_id: device_id,
        appengine_client: appengine_client
      } = deployment.device

      resource_id =
        deployment
        |> Map.fetch!(resource_id_key)
        |> to_string()

      with :ok <- validate_appengine_client_exist(appengine_client),
           {:ok, events} <-
             @resource_event_module.get(
               appengine_client,
               device_id,
               interface,
               resource_id,
               query
             ) do
        Enum.map(events, &cast_event!(deployment, &1, event_type))
      else
        {:error, _reason} -> nil
      end
    end)
  end

  def cast_event!(record, event, event_type) do
    input = %{
      resource_id: AshGraphql.Resource.encode_relay_id(record),
      status: Macro.underscore(event.status),
      message: event.message || "",
      add_info: event.add_info || [],
      timestamp: event.timestamp
    }

    {:ok, value} = Ash.Type.cast_input(event_type, input, event_type.subtype_constraints())
    value
  end

  defp validate_appengine_client_exist(nil), do: {:error, :appengine_client_not_loaded}
  defp validate_appengine_client_exist(_), do: :ok

  defp maybe_add_limit(opts, nil), do: opts
  defp maybe_add_limit(opts, limit), do: [{:limit, limit} | opts]
end
