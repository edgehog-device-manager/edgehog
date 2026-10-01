#
# This file is part of Edgehog.
#
# Copyright 2021-2026 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device.StorageUsage.StorageUnit do
  @moduledoc """
  Device storage units. They represent a storage available on a device and
  provide insightful data on it:

  - label       :: is the storage identification label. Unique per storage unit.
  - mounts      :: is a list of paths mounted on the device.
  - name        :: an optional name for the storage
  - fstype      :: the filesystem type of the storage unit
  - kind        :: the storage unit kind
  - total_bytes :: the storage unit total bytes
  - free_bytes  :: the storage unit free bytes
  """
  @enforce_keys [:label]

  defstruct [
    :label,
    :mounts,
    :name,
    :fstype,
    :kind,
    :total_bytes,
    :free_bytes
  ]

  @type t() :: %__MODULE__{
          label: String.t(),
          mounts: list(String.t()) | nil,
          name: String.t() | nil,
          fstype: String.t() | nil,
          kind: String.t() | nil,
          total_bytes: integer() | nil,
          free_bytes: integer() | nil
        }
end
