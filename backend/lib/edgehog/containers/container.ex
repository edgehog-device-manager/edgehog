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

  alias Edgehog.Containers.Container.EnvJsonEncoding
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Types.RestartPolicy

  actions do
    defaults [
      :read,
      :destroy,
      create: [:restart_policy, :hostname, :env, :privileged],
      update: [:restart_policy, :hostname, :env, :privileged]
    ]
  end

  attributes do
    uuid_primary_key :id

    attribute :restart_policy, RestartPolicy

    attribute :hostname, :string do
      default ""
    end

    attribute :env, :map do
      default %{}
    end

    attribute :privileged, :boolean do
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :image, Image do
      source_attribute :image_id
      attribute_type :uuid
    end

    many_to_many :releases, Edgehog.Containers.Release do
      through Edgehog.Containers.ReleaseContainers
    end
  end

  calculations do
    calculate :env_json, :string, EnvJsonEncoding
  end

  postgres do
    table "containers"
  end
end
