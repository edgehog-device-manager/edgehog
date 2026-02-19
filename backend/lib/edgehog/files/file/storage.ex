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

defmodule Edgehog.Files.File.Storage do
  @moduledoc """
  Behaviour for file storage implementations.
  """

  alias Edgehog.Files.File

  @type upload :: %Plug.Upload{}

  @callback store(
              tenant_id :: String.t() | integer(),
              file_name :: String.t(),
              repository_id :: String.t() | integer(),
              file :: upload()
            ) ::
              {:ok, file_url :: String.t()} | {:error, reason :: any()}

  @callback delete(file :: %File{}) ::
              :ok | {:error, reason :: any()}
end
