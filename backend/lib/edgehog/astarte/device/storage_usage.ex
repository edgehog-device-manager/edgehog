#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device.StorageUsage do
  @behaviour Edgehog.Astarte.Device.StorageUsage.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.StorageUsage.StorageUnit

  @interface "io.edgehog.devicemanager.StorageUsage"

  def get(%AppEngine{} = client, device_id) do
    # TODO: right now we request the whole interface at once and longinteger
    # values are returned as strings by Astarte, since the interface is of
    # type Object Aggregrate.
    # For details, see https://github.com/astarte-platform/astarte/issues/630
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @interface, limit: 1) do
      storage_units =
        data
        |> Enum.map(fn
          {label, [storage_unit]} -> parse_storage_unit(label, storage_unit)
          # TODO: handle value as single object too, as a workaround for the issue:
          # https://github.com/astarte-platform/astarte/issues/707
          {label, storage_unit} -> parse_storage_unit(label, storage_unit)
        end)

      {:ok, storage_units}
    end
  end

  defp parse_storage_unit(unit_label, storage_unit) when is_binary(unit_label) do
    %StorageUnit{
      label: unit_label,
      total_bytes: parse_longinteger(storage_unit["totalBytes"]),
      free_bytes: parse_longinteger(storage_unit["freeBytes"])
    }
  end

  defp parse_longinteger(string) when is_binary(string) do
    case Integer.parse(string) do
      {integer, _remainder} -> integer
      _ -> nil
    end
  end

  defp parse_longinteger(_term) do
    nil
  end
end
