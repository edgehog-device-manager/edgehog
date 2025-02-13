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

defmodule Edgehog.Containers.Types.DeploymentStatus do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      deleting: "The deployment is being deleted",
      error: "The deployment process entered an error state.",
      started: "The deployment is running.",
      starting: "The deployment is starting.",
      stopped: "The deployment has stopped.",
      stopping: "The deploymen is stopping.",
      created: "The deployment has been received by the backend and will be sent to the device.",
      sent: "All the necessary resources have been sent to the device.",
      # TODO: these are internal states that should not be exposed.
      # Remove when reimplementing the deployment and its status as a state machine
      created_images: "The device has received the necessary image descriptions for the deployment.",
      created_networks: "The device has received all the network descriptions necessary for the deployment.",
      created_volumes: "The device has received all the volume descriptions necessary for the deployment.",
      created_containers: "The device has received all the container descriptions necessary for the deployment.",
      created_deployment: "The device has received the release description of the the deployment."
    ]

  def graphql_type(_), do: :application_deployment_status
end
