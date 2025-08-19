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

defmodule Edgehog.Astarte.Device.CreateContainerRequest.RequestData do
  @moduledoc false

  # TODO the interface for now has the :image key, this is a device
  # problem, once solved it should be removed

  defstruct [
    :id,
    :deploymentId,
    :imageId,
    :networkIds,
    :hostname,
    :restartPolicy,
    :env,
    :binds,
    :volumeIds,
    :networkMode,
    :portBindings,
    :extraHosts,
    :capAdd,
    :capDrop,
    :deviceMappingIds,
    :cpuPeriod,
    :cpuQuota,
    :cpuRealTimePeriod,
    :cpuRealtimeRuntime,
    :memory,
    :memoryReservation,
    :memorySwap,
    :memorySwappiness,
    :volumeDriver,
    :storageOpt,
    :readOnlyRootfs,
    :tmpfs,
    :privileged
  ]

  @type t() :: %__MODULE__{
          id: String.t(),
          deploymentId: String.t(),
          imageId: String.t(),
          volumeIds: list(String.t()),
          hostname: String.t(),
          restartPolicy: String.t(),
          env: list(tuple()),
          binds: list(String.t()),
          networkIds: list(String.t()),
          networkMode: String.t(),
          portBindings: list(String.t()),
          extraHosts: list(String.t()),
          capAdd: list(String.t()),
          capDrop: list(String.t()),
          deviceMappingIds: list(String.t()),
          cpuPeriod: integer(),
          cpuQuota: integer(),
          cpuRealTimePeriod: integer(),
          cpuRealtimeRuntime: integer(),
          memory: integer(),
          memoryReservation: integer(),
          memorySwap: integer(),
          memorySwappiness: integer(),
          volumeDriver: String.t(),
          storageOpt: list(String.t()),
          readOnlyRootfs: boolean(),
          tmpfs: list(String.t()),
          privileged: String.t()
        }
end
