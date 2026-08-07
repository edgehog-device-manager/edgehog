# This file is part of Edgehog.
#
# Copyright 2025, 2026 SECO Mind Srl
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

defmodule Edgehog.Containers.DeviceMapping.Deployment.Changes.DeployDeviceMappingOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Resource.Change
  alias Edgehog.Containers.DeviceMapping.Deployment.Provisioner

  @impl Change
  def change(changeset, _opts, %{tenant: tenant}) do
    deployment = Ash.Changeset.get_argument(changeset, :deployment)
    device_mapping_deployment = changeset.data

    Ash.Changeset.after_action(changeset, fn _changeset, result ->
      Provisioner.provision(device_mapping_deployment, deployment, tenant)

      {:ok, result}
    end)
  end
end
