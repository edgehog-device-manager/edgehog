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

defmodule Edgehog.Containers.DeviceMapping.Deployment do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource],
    data_layer: AshPostgres.DataLayer

  graphql do
    type :deployment
  end

  actions do
    defaults [:read, :destroy, create: []]
  end

  attributes do
    uuid_primary_key :id

    attribute :last_message, :string
    attribute :state, :atom
    timestamps()
  end

  relationships do
    belongs_to :device_mapping, Edgehog.Containers.DeviceMapping
    belongs_to :device, Edgehog.Devices.Device
  end

  postgres do
    table "deployments"
    repo Edgehog.Repo
  end
end
