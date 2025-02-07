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

defmodule Edgehog.Containers.Deployment.Types.DeploymentState do
  @moduledoc false

  use Ash.Type.Enum,
    values: [
      created: "The deployment has been created in the database layer, the device yet has to receive it.",
      sent: "The deployment description has been sent to the device.",
      deleting: "The device is deleting the deployment.",
      error: "The device reported an error. Check `last_error_message` for the error message.",
      started: "The deployment is started on the device.",
      starting: "The device is starting the deployment.",
      stopped: "The deployment is stopped on the device.",
      stopping: "The device is stopping the deployment."
    ]

  def graphql_type(_), do: :application_deployment_state
end
