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

defmodule Edgehog.Astarte.Device.FileDownloadRequest.RequestData do
  @moduledoc """
  Struct representing the data needed to request a file download on an Astarte device.
  """

  alias Edgehog.Files.FileDownloadRequest.FileDestination

  defstruct [
    :id,
    :url,
    :httpHeaderKey,
    :httpHeaderValue,
    :compression,
    :fileSizeBytes,
    :progress,
    :digest,
    :fileName,
    :ttlSeconds,
    :fileMode,
    :userId,
    :groupId,
    :destination
  ]

  @type t() :: %__MODULE__{
          id: String.t(),
          url: String.t(),
          httpHeaderKey: String.t(),
          httpHeaderValue: String.t(),
          compression: String.t(),
          fileSizeBytes: non_neg_integer() | nil,
          progress: boolean(),
          digest: String.t() | nil,
          fileName: String.t() | nil,
          ttlSeconds: non_neg_integer(),
          fileMode: non_neg_integer(),
          userId: integer(),
          groupId: integer(),
          destination: FileDestination.t()
        }
end
