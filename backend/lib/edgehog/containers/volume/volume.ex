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

defmodule Edgehog.Containers.Volume do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers

  alias Edgehog.Containers.Volume.Calculations

  actions do
    defaults [
      :read,
      :destroy,
      create: [:driver, :options],
      update: [:driver, :options]
    ]
  end

  attributes do
    uuid_primary_key :id

    attribute :driver, :string do
      default "local"
      allow_nil? false
    end

    attribute :options, :map do
      default %{}
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    many_to_many :devices, Edgehog.Devices.Device do
      through Edgehog.Containers.Volume.Deployment
      join_relationship :volume_deployments
    end
  end

  calculations do
    calculate :options_encoding, {:array, :string}, Calculations.OptionsEncoding
  end

  postgres do
    table "volumes"
  end
end
