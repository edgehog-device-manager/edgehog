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

defmodule Edgehog.Geolocation.Position do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [
      AshGraphql.Resource
    ]

  resource do
    description """
    Describes the position of a device.

    The field holds information about the GPS coordinates of the device,
    which are estimated by means of Edgehog's geolocation modules and the
    data published by the device.
    """
  end

  graphql do
    type :position
  end

  attributes do
    attribute :latitude, :float do
      description "The latitude coordinate."
      public? true
      allow_nil? false
    end

    attribute :longitude, :float do
      description "The longitude coordinate."
      public? true
      allow_nil? false
    end

    attribute :accuracy, :float do
      description "The accuracy of the measurement, in meters."
      public? true
    end

    attribute :altitude, :float do
      description "The altitude coordinate."
      public? true
    end

    attribute :altitude_accuracy, :float do
      description "The accuracy of the altitude measurement, in meters."
      public? true
    end

    attribute :heading, :float do
      description "The measured heading."
      public? true
    end

    attribute :speed, :float do
      description "The measured speed."
      public? true
    end

    attribute :timestamp, :datetime do
      description "The date and time at which the measurement was made."
      public? true
      allow_nil? false
    end

    attribute :source, :string do
      description "Describes how the position was calculated."
      public? true
    end
  end
end
