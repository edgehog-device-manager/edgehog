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

defmodule Edgehog.Containers.Deployment.Types.DeploymentContext do
  @moduledoc """
  Deployment context. An auxiliary type to track requests and pending operations on a deployment.
  """

  use Ash.Type.Enum,
    values: [
      start_message_sent:
        "A `start` message has been sent to the device. We expect either a state transition to `started` or an `error` event",
      stop_message_sent:
        "A `stop` message has been sent to the device. We expect either a state transition to `stopped` or an `error` event",
      upgrade_message_sent:
        "An `upgrade` message has been sent to the device. We expect either a :stop on the record, or an `error` event",
      delete_message_sent:
        "A `delete` message has been sent to the device. We expect either a :destroy on the record, or an `error` event"
    ]
end
