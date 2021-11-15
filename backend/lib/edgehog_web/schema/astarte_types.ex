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

defmodule EdgehogWeb.Schema.AstarteTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias EdgehogWeb.Middleware
  alias EdgehogWeb.Resolvers

  object :hardware_info do
    field :cpu_architecture, :string
    field :cpu_model, :string
    field :cpu_model_name, :string
    field :cpu_vendor, :string
    # TODO: since these is longinteger, should this be a string?
    field :memory_total_bytes, :integer
  end

  object :device_location do
    field :latitude, non_null(:float)
    field :longitude, non_null(:float)
    field :accuracy, :float
    field :address, :string
    field :timestamp, non_null(:datetime)
  end

  object :wifi_scan_result do
    field :channel, :integer
    field :essid, :string
    field :mac_address, :string
    field :rssi, :integer
    field :timestamp, non_null(:datetime)
  end

  node object(:device) do
    field :name, non_null(:string)
    field :device_id, non_null(:string)
    field :online, non_null(:boolean)
    field :last_connection, :datetime
    field :last_disconnection, :datetime

    field :hardware_info, :hardware_info do
      resolve &Resolvers.Astarte.get_hardware_info/3
      middleware Middleware.ErrorHandler
    end

    field :location, :device_location do
      resolve &Resolvers.Astarte.fetch_device_location/3
      middleware Middleware.ErrorHandler
    end

    field :wifi_scan_results, list_of(non_null(:wifi_scan_result)) do
      resolve &Resolvers.Astarte.fetch_wifi_scan_results/3
      middleware Middleware.ErrorHandler
    end
  end

  object :astarte_queries do
    @desc "List devices"
    field :devices, non_null(list_of(non_null(:device))) do
      resolve &Resolvers.Astarte.list_devices/3
    end

    @desc "Get a single device"
    field :device, :device do
      arg :id, non_null(:id)
      middleware Absinthe.Relay.Node.ParseIDs, id: :device
      resolve &Resolvers.Astarte.find_device/2
    end
  end
end
