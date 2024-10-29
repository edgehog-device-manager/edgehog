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

  # TODO the interface for now has the :image key, this is a device
  # problem, once solved it should be removed

  defstruct [
    :id,
    :imageId,
    :networkIds,
    :volumeIds,
    :hostname,
    :restartPolicy,
    :env,
    :binds,
    :networks,
    :portBindings,
    :privileged
  ]

  @type t() :: %__MODULE__{
          id: String.t(),
          imageId: String.t(),
          networkIds: list(String.t()),
          volumeIds: list(String.t()),
          hostname: String.t(),
          restartPolicy: String.t(),
          env: list(tuple()),
          binds: list(String.t()),
          networks: list(String.t()),
          portBindings: list(String.t()),
          privileged: String.t()
        }
end
