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

defmodule Edgehog.Files do
  @moduledoc """
  The `Edgehog.Files` domain, which includes resources and logic related to file management.
  """

  use Ash.Domain,
    extensions: [AshGraphql.Domain]

  alias Edgehog.Files.File
  alias Edgehog.Files.FileDownloadRequest
  alias Edgehog.Files.Repository

  graphql do
    root_level_errors? true

    queries do
      # get File, :file, :read do
      #   description "Returns a single file."
      # end

      get Repository, :repository, :read do
        description "Returns a single repository."
      end

      list Repository, :repositories, :read do
        description "Returns a list of repositories."
        relay? true
        paginate_with :keyset
      end
    end

    mutations do
      create File, :create_file, :create do
        relay_id_translations input: [repository_id: :repository]
      end

      destroy File, :delete_file, :destroy

      create Repository, :create_repository, :create
      update Repository, :update_repository, :update
      destroy Repository, :delete_repository, :destroy

      create FileDownloadRequest, :create_file_download_request, :manual do
        relay_id_translations input: [device_id: :device]
      end
    end
  end

  resources do
    resource File
    resource Repository

    resource FileDownloadRequest do
      define :send_file_download_request, args: [:file_download_request]
    end
  end
end
