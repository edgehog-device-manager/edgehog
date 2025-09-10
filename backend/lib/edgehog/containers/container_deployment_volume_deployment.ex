#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.ContainerDeploymentVolumeDeployment do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers,
    data_layer: AshPostgres.DataLayer

  actions do
    defaults [:read, :destroy, create: []]
  end

  relationships do
    belongs_to :container_deployment, Edgehog.Containers.Container.Deployment do
      primary_key? true
      allow_nil? false
    end

    belongs_to :volume_deployment, Edgehog.Containers.Volume.Deployment do
      primary_key? true
      allow_nil? false
    end
  end

  postgres do
    table "container_deployment_volume_deployments"
    repo Edgehog.Repo
  end
end
