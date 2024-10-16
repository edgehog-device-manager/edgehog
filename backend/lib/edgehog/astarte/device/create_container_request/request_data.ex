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

defmodule Edgehog.Astarte.Device.CreateContainerRequest.RequestData do
  @moduledoc false
  defstruct [
    :container_id,
    :image_id,
    :networks_ids,
    :volume_ids,
    :hostname,
    :restart_policy,
    :env,
    :binds,
    :networks,
    :port_bindings,
    :privileged
  ]

  @type t() :: %__MODULE__{
          container_id: String.t(),
          image_id: String.t(),
          networks_ids: list(String.t()),
          volume_ids: list(String.t()),
          hostname: String.t(),
          restart_policy: String.t(),
          env: list(tuple()),
          binds: list(String.t()),
          networks: list(String.t()),
          port_bindings: list(String.t()),
          privileged: String.t()
        }
end
