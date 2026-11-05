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

defmodule Edgehog.Containers.AllowedRegistry do
  @moduledoc false
  use Edgehog.MultitenantResource,
    extensions: [AshGraphql.Resource],
    domain: Edgehog.Containers

  graphql do
    type :allowed_registry
  end

  actions do
    defaults [:read, :destroy, create: [:registry], update: [:registry]]
  end

  validations do
    validate {Edgehog.Containers.Validations.RegistryHost, []}
  end

  attributes do
    uuid_primary_key :id

    attribute :registry, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  postgres do
    table "allowed_registries"
  end
end
