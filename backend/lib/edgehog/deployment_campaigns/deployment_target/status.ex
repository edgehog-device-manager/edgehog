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

defmodule Edgehog.DeploymentCampaigns.DeploymentTarget.Status do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      idle: "The deployment target is waiting for the deployment to start.",
      in_progress: "The deployment is in progress.",
      failed: "Something went wrong while deploying the target.",
      successful: "The release has been successfully deployed to the target."
    ]

  def graphql_type(_), do: :deployment_target_status
end
