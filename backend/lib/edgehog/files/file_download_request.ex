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

defmodule Edgehog.Files.FileDownloadRequest do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Files,
    extensions: [AshGraphql.Resource],
    data_layer: AshPostgres.DataLayer

  graphql do
    type :file_download_request
  end

  actions do
    defaults [:read, :destroy]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :url, :string do
      allow_nil? false
      public? true
    end

    attribute :file_name, :string do
      public? true
    end

    attribute :uncompressed_file_size_bytes, :integer do
      public? true
    end

    attribute :digest, :string do
      public? true
    end

    attribute :compression, :string do
      public? true
    end

    attribute :ttl_seconds, :integer do
      public? true
    end

    attribute :file_mode, :integer do
      public? true
    end

    attribute :user_id, :integer do
      public? true
    end

    attribute :group_id, :integer do
      public? true
    end

    attribute :destination, :string do
      public? true
    end

    attribute :progress, :boolean do
      public? true
    end

    attribute :status, :string do
      public? true
    end

    attribute :status_progress, :integer do
      public? true
    end

    attribute :status_code, :integer do
      public? true
    end

    attribute :message, :string do
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
    table "file_download_requests"
    repo Edgehog.Repo
  end
end
