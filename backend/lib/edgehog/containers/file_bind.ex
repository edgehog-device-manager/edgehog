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

defmodule Edgehog.Containers.FileBind do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource],
    notifiers: [Ash.Notifier.PubSub]

  graphql do
    type :file_bind
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:container_deployment_id, :file_mount_id]

      argument :file_download_request_id, :uuid
      argument :device_file_id, :uuid

      change manage_relationship(:file_download_request_id, :file_download_request, type: :append)

      change manage_relationship(:device_file_id, :device_file, type: :append)

      validate Edgehog.Containers.FileBind.Validations.HasTarget
    end

    create :create_fixture do
      accept [:container_deployment_id, :file_download_request_id, :device_file_id]
    end
  end

  attributes do
    uuid_v7_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :container_deployment, Edgehog.Containers.Container.Deployment do
      attribute_type :uuid
      allow_nil? false
    end

    belongs_to :file_mount, Edgehog.Containers.Container.FileMount do
      attribute_type :uuid_v7
    end

    belongs_to :file_download_request, Edgehog.Files.FileDownloadRequest do
      attribute_type :uuid_v7
    end

    belongs_to :device_file, Edgehog.Files.DeviceFile do
      attribute_type :uuid_v7
    end
  end

  pub_sub do
    prefix "file_binds"
    module EdgehogWeb.Endpoint
  end

  postgres do
    table "container_deployment_file_binds"
    repo Edgehog.Repo

    references do
      reference :container_deployment, on_delete: :delete
    end
  end
end
