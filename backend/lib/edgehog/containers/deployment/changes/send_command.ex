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

defmodule Edgehog.Containers.Deployment.Changes.SendCommand do
  @moduledoc """
  A change to send a command to a deployment _after_ the action has been done.

  This ensures that the communication with the device happens only when the
  database has been updated with relevant information _and_ in case of success
  """
  use Ash.Resource.Change

  alias Edgehog.Devices

  @impl Ash.Resource.Change
  def change(changeset, opts, _context) do
    command = Keyword.fetch!(opts, :command)

    Ash.Changeset.after_action(changeset, &send_command(&1, &2, command))
  end

  defp send_command(changeset, deployment, command) do
    %{tenant: tenant} = changeset

    with {:ok, deployment} <- Ash.load(deployment, [:device, :release]),
         device = deployment.device,
         release = deployment.release,
         {:ok, _device} <-
           Devices.send_release_command(device, release, command, tenant: tenant) do
      {:ok, deployment}
    end
  end
end
