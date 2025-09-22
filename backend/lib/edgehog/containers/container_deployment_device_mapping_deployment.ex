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

defmodule Edgehog.Containers.ContainerDeploymentDeviceMappingDeployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    tenant_id_in_primary_key?: true

  actions do
    defaults [:read, :destroy, create: [:container_deployment_id, :device_mapping_deployment_id]]
  end

  relationships do
    belongs_to :container_deployment, Edgehog.Containers.Container.Deployment do
      primary_key? true
      allow_nil? false
      attribute_type :uuid
    end

    belongs_to :device_mapping_deployment, Edgehog.Containers.DeviceMapping.Deployment do
      primary_key? true
      allow_nil? false
      attribute_type :uuid
    end
  end

  postgres do
    table "container_deployment_device_mapping_deployments"

    references do
      reference :container_deployment, on_delete: :delete
      reference :device_mapping_deployment, on_delete: :delete
    end
  end
end
