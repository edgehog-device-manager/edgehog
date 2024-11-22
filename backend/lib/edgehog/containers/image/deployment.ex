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

defmodule Edgehog.Containers.Image.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Image.Changes

  graphql do
    type :image_deployment
  end

  actions do
    defaults [:read, :destroy, create: [:pulled], update: [:pulled]]

    create :deploy do
      description """
      Deploys an image on a device, the status according to device triggers.
      """

      accept [:image_id]

      argument :device_id, :id do
        allow_nil? false
      end

      change manage_relationship(:device_id, :device, type: :append)

      change Changes.DeployImageOnDevice
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :pulled, :boolean do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :image, Edgehog.Containers.Image do
      attribute_type :uuid
      public? true
    end

    belongs_to :device, Edgehog.Devices.Device
  end

  postgres do
    table "image_deployments"

    references do
      reference :image, on_delete: :delete
      reference :device, on_delete: :delete
    end
  end
end
