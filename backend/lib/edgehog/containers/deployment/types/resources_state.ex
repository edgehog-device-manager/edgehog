#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment.Types.ResourcesState do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      initial: "The backend has not checked the state of the underlying resources of the deployment with the device.",
      created_images: "The device has received the necessary image descriptions for the deployment.",
      created_networks: "The device has received all the network descriptions necessary for the deployment.",
      created_volumes: "The device has received all the volume descriptions necessary for the deployment.",
      created_device_mappings:
        "The device has received all the device file mappings descriptions necessary for the deployment.",
      created_containers: "The device has received all the container descriptions necessary for the deployment.",
      ready: "All the underlying resources needed for the deployment have been received by the device."
    ]

  def graphql_type(_), do: :application_deployment_resources_state
end
