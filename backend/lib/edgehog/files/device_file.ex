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

defmodule Edgehog.Files.DeviceFile do
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Files,
    extensions: [AshGraphql.Resource],
    data_layer: AshPostgres.DataLayer

  graphql do
    type :device_file
  end

  actions do
    defaults [:read, :destroy, create: [:file_id, :path_on_device, :size_bytes]]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :file_id, :string do
      allow_nil? false
      public? true
    end

    attribute :path_on_device, :string do
      public? true
    end

    attribute :size_bytes, :integer do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :device, Edgehog.Devices.Device do
      allow_nil? false
      public? true
    end
  end

  postgres do
    table "device_files"
    repo Edgehog.Repo
  end
end
