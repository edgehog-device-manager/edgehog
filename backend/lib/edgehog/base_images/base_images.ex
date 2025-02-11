#
# This file is part of Edgehog.
#
# Copyright 2022-2025 SECO Mind Srl
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

defmodule Edgehog.BaseImages do
  @moduledoc """
  The BaseImages context.
  """

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.BaseImages.BaseImageCollection

  graphql do
    root_level_errors? true

    queries do
      get BaseImage, :base_image, :read do
        description "Returns a single base image."
      end

      get BaseImageCollection, :base_image_collection, :read do
        description "Returns a single base image collection."
      end

      list BaseImageCollection, :base_image_collections, :read do
        description "Returns a list of base image collections."
        paginate_with nil
      end
    end

    mutations do
      create BaseImage, :create_base_image, :create do
        relay_id_translations input: [base_image_collection_id: :base_image_collection]
      end

      update BaseImage, :update_base_image, :update
      destroy BaseImage, :delete_base_image, :destroy

      create BaseImageCollection, :create_base_image_collection, :create do
        relay_id_translations input: [system_model_id: :system_model]
      end

      update BaseImageCollection, :update_base_image_collection, :update
      destroy BaseImageCollection, :delete_base_image_collection, :destroy
    end
  end

  resources do
    resource BaseImage do
      define :delete_base_image, action: :destroy
    end

    resource BaseImageCollection
  end
end
