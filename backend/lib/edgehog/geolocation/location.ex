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

defmodule Edgehog.Geolocation.Location do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [
      AshGraphql.Resource
    ]

  resource do
    description """
    Describes the place where a device is located.

    The field holds information about the device's address, which is
    estimated by means of Edgehog's geolocation modules and the data
    published by the device.
    """
  end

  graphql do
    type :location
  end

  attributes do
    attribute :formatted_address, :string do
      description "The formatted address associated with the location."
      public? true
      allow_nil? false
    end

    attribute :timestamp, :datetime do
      description "The date and time at which the location was measured."
      public? true
      allow_nil? false
    end

    attribute :source, :string do
      description "Describes how the location was calculated."
      public? true
    end
  end
end
