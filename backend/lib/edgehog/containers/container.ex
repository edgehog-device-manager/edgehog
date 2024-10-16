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

defmodule Edgehog.Containers.Container do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers

  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Container.EnvJsonEncoding

  actions do
    defaults [:read, :destroy, :create, :update]
  end

  calculations do
    calculate :env_json, :string, EnvJsonEncoding
  end
  

  attributes do
    uuid_primary_key :id

    attribute :restart_policy, :restart_policy do
      public? true
      default nil
    end

    attribute :hostname, :string do
      public? true
      default ""
    end

    attribute :env, :map do
      public? true
      default %{}
    end

    attribute :privileged, :boolean do
      public? true
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :image, Image do
      source_attribute :image_id
      attribute_type :uuid
    end
  end

  postgres do
    table "containers"
  end
end
