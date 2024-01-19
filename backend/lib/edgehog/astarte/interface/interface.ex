#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.Astarte.Interface do
  alias Astarte.Client.APIError
  alias Astarte.Client.RealmManagement
  alias Edgehog.Astarte.Interface.AstarteDataLayer

  @data_layer Application.compile_env(:edgehog, :astarte_interface_data_layer, AstarteDataLayer)

  def fetch_by_name_and_major(%RealmManagement{} = client, interface_name, interface_major) do
    case @data_layer.get(client, interface_name, interface_major) do
      {:ok, %{"data" => interface_map}} ->
        {:ok, interface_map}

      {:error, %APIError{status: 404}} ->
        # We just convert a 404 status to :not_found, and return all other errors as-is
        {:error, :not_found}

      {:error, other} ->
        {:error, other}
    end
  end

  defdelegate create(client, interface_json), to: @data_layer
  defdelegate update(client, interface_name, interface_major, interface_json), to: @data_layer
end
