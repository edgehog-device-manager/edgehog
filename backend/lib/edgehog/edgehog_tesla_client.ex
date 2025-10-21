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

defmodule Edgehog.EdgehogTeslaClient do
  @moduledoc false

  def client do
    Tesla.client(middleware(), adapter())
  end

  defp middleware do
    [
      Tesla.Middleware.KeepRequest,
      Tesla.Middleware.PathParams,
      Tesla.Middleware.JSON
    ]
  end

  defp adapter do
    :edgehog
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:adapter)
  end

  def get(url, opts \\ []) do
    Tesla.get(client(), url, opts)
  end

  def post(url, body, opts \\ []) do
    Tesla.post(client(), url, body, opts)
  end
end
