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

defmodule Edgehog.Containers.Deployment.EventType do
  @moduledoc """
  Expresses the type of event a device can communicate to the backend trough the `DeploymentEvent` interface.
  """

  use Ash.Type.Enum,
    values: [
      starting: "The deployment is starting.",
      stopping: "The deployment is stopping.",
      started: "The deployment is started.",
      stopped: "The deployment is stopped.",
      updating: "The deployment is getting updated.",
      deleting: "The deployment is getting deleted.",
      error: "The deployment encountered an error."
    ]

  def graphql_type(_), do: :deployment_event_type
end
