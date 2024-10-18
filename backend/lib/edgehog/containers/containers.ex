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

defmodule Edgehog.Containers do
  @moduledoc false
  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  alias Edgehog.Containers.ImageCredentials

  graphql do
    root_level_errors? true

    queries do
      get ImageCredentials, :image_credentials, :read do
        description "Returns the desired image credentials."
      end

      list ImageCredentials, :list_image_credentials, :read do
        description "Returns all available image credentials."
        paginate_with nil
      end
    end

    mutations do
      create ImageCredentials, :create_image_credentials, :create do
        description "Create image credentials."
      end

      destroy ImageCredentials, :delete_image_credentials, :destroy
    end
  end

  resources do
    resource Edgehog.Containers.Application
    resource Edgehog.Containers.Image
    resource Edgehog.Containers.ImageCredentials
  end
end
