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

defmodule Edgehog.Campaigns.CampaignMechanism.FileDownload do
  @moduledoc """
  Defines the File Download Campaign Mechanism resource.
  This resource represents the configuration for a file download operation within a file download campaign.
  """

  use Ash.Resource,
    extensions: [
      AshGraphql.Resource
    ],
    data_layer: :embedded

  alias Edgehog.Files.File
  alias Edgehog.Files.FileDownloadRequest.FileDestination

  resource do
    description """
    An object representing the properties of a File Download campaign mechanism.
    """
  end

  graphql do
    type :file_download
  end

  attributes do
    attribute :type, :atom do
      description """
      The type of rollout.

      This field is used to distinguish this mechanism from others.
      """

      constraints one_of: [:file_download]
      allow_nil? false
      default :file_download
    end

    attribute :max_failure_percentage, :float do
      description """
      The maximum percentage of failures allowed over the number of total targets.
      If the failures exceed this threshold, the File Download Campaign terminates with
      a failure.
      """

      public? true
      allow_nil? false
      constraints min: 0, max: 100
    end

    attribute :max_in_progress_operations, :integer do
      description """
      The maximum number of in progress file downloads. The File Download Campaign will
      have at most this number of File Download Requests that are started but not yet
      finished (either successfully or not).
      """

      public? true
      allow_nil? false
      constraints min: 1
    end

    attribute :request_retries, :integer do
      description """
      The number of attempts that have to be tried before giving up on the
      file download of a specific target (and considering it an error). Note that the
      file download is retried only if the request doesn't get acknowledged from the
      device.
      """

      public? true
      allow_nil? false
      default 3
      constraints min: 0
    end

    attribute :request_timeout_seconds, :integer do
      description """
      The timeout (in seconds) Edgehog has to wait before considering a
      File Download Request lost (and possibly retry). It must be at least 30 seconds.
      """

      public? true
      allow_nil? false
      default 300
      constraints min: 30
    end

    attribute :compression, :string do
      description """
      Optional compression type for the file (e.g., "tar.gz").
      Other values are: ['tar.gz']. Defaults to empty string (no compression).
      """

      public? true
      default ""
    end

    attribute :ttl_seconds, :integer do
      description """
      Optional ttl for how long to keep the file for on the device, if 0 is forever.
      Defaults to 0.
      """

      public? true
      default 0
    end

    attribute :file_mode, :integer do
      description """
      Optional unix mode for the file (e.g., 0o644 for readable by all, writable by owner).
      Set to 0 to use device default. Defaults to 0.
      """

      public? true
      default 0
    end

    attribute :user_id, :integer do
      description """
      Optional unix uid of the user owning the file. Set to -1 to use device default.
      Defaults to -1.
      """

      public? true
      default -1
    end

    attribute :group_id, :integer do
      description """
      Optional unix gid of the group owning the file. Set to -1 to use device default.
      Defaults to -1.
      """

      public? true
      default -1
    end

    attribute :destination_type, FileDestination do
      description """
      Device-specific field indicating where the file should be stored.
      Supported values are: storage, streaming, filesystem.
      """

      public? true
      allow_nil? false
    end

    attribute :destination, :string do
      description """
      Destination-specific information on where to write the file to.
      Required when destination_type is :filesystem.
      """

      public? true
    end
  end

  relationships do
    belongs_to :file, File do
      description "The file to be downloaded by the campaign."
      public? true
      attribute_type :uuid
    end
  end
end
