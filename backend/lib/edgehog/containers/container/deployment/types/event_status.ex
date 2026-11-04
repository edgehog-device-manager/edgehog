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

defmodule Edgehog.Containers.Container.Deployment.Types.EventStatus do
  @moduledoc """
  Expresses the status of an event a device can communicate to the backend through the `ContainerEvent` interface.
  """

  use Ash.Type.Enum,
    values: [
      :create,
      :start,
      :restart,
      :stop,
      :die,
      :kill,
      :destroy,
      :prune,
      :oom,
      :attach,
      :commit,
      :copy,
      :detach,
      :exec_create,
      :exec_detach,
      :exec_start,
      :exec_die,
      :export,
      :health_status,
      :pause,
      :rename,
      :resize,
      :top,
      :unpause,
      :update,
      :error
    ]

  def graphql_type(_), do: :container_deployment_event_status

  # Ash.Type.Enum expects snake_case input and lowercases everything.
  # Explicitly match multi-word PascalCase status strings sent by Astarte.
  def match("ExecCreate"), do: {:ok, :exec_create}
  def match("ExecDetach"), do: {:ok, :exec_detach}
  def match("ExecStart"), do: {:ok, :exec_start}
  def match("ExecDie"), do: {:ok, :exec_die}
  def match("HealthStatus"), do: {:ok, :health_status}
  def match(term), do: super(term)
end
