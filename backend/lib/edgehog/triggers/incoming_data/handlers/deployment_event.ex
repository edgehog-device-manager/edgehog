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

defmodule Edgehog.Triggers.IncomingData.Handlers.DeploymentEvent do
  @moduledoc """
  Available Images handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Containers

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, %{tenant: tenant}) do
    "/" <> deployment_id = event.path

    %{
      "status" => state,
      "message" => message
    } = event.value

    add_info = Map.get(event.value, "addInfo")

    with {:ok, deployment} <- Containers.fetch_deployment(deployment_id, tenant: tenant) do
      event =
        case add_info do
          nil -> %{type: state, message: message}
          _ -> %{type: state, message: message, addInfo: add_info}
        end

      Containers.append_deployment_event(deployment, %{event: event}, tenant: tenant)
    end
  end
end
