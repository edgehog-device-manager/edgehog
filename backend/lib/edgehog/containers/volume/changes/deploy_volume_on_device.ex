#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Containers.Volume.Changes.DeployVolumeOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    device = Ash.Changeset.get_argument(changeset, :device)
    volume = Ash.Changeset.get_argument(changeset, :volume)

    Ash.Changeset.after_action(changeset, fn _changeset, volume_deployment ->
      with {:ok, _device} <- Devices.send_create_volume_request(device, volume) do
        Containers.mark_volume_deployment_as_sent(volume_deployment)
      end
    end)
  end
end
