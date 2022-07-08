#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.GeolocationTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  @desc """
  Describes the position of a device.

  The position is estimated by means of Edgehog's Geolocation modules and the \
  data published by the device.
  """
  object :device_location do
    @desc "The latitude coordinate."
    field :latitude, non_null(:float)

    @desc "The longitude coordinate."
    field :longitude, non_null(:float)

    @desc "The accuracy of the measurement, in meters."
    field :accuracy, :float

    @desc "The formatted address estimated for the position."
    field :address, :string

    @desc "The date at which the measurement was made."
    field :timestamp, non_null(:datetime)
  end
end
