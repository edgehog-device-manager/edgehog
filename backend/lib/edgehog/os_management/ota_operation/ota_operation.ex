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

defmodule Edgehog.OSManagement.OTAOperation do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.OSManagement,
    extensions: [
      AshGraphql.Resource
    ],
    notifiers: [Ash.Notifier.PubSub]

  alias Edgehog.OSManagement.OTAOperation.Changes
  alias Edgehog.OSManagement.OTAOperation.ManualActions
  alias Edgehog.OSManagement.OTAOperation.Status
  alias Edgehog.OSManagement.OTAOperation.StatusCode

  @terminal_statuses [:success, :failure]

  resource do
    description """
    An OTA update operation
    """
  end

  graphql do
    type :ota_operation

    field_names inserted_at: :created_at
  end

  actions do
    defaults [:read]

    create :create_fixture do
      accept [
        :base_image_url,
        :status,
        :status_progress,
        :status_code,
        :message,
        :manual?,
        :device_id
      ]
    end

    create :create_managed do
      description "Initiates an OTA update with base image's URL"

      accept [:base_image_url, :device_id]

      change Changes.SendUpdateRequest
    end

    create :manual do
      description "Initiates an OTA update with a user provided OS image"

      argument :device_id, :id do
        description "The ID identifying the Device the OTA Operation will be sent to"
        allow_nil? false
      end

      argument :base_image_file, Edgehog.Types.Upload do
        description "The base image file, which will be uploaded to the storage."
        allow_nil? false
      end

      # Manually generate the ID since it's needed by HandleFileUpload before we hit the DB
      change set_attribute(:id, &Ash.UUID.generate/0)

      # We eager check the existence of the device to avoid uploading the image if it doesn't exist
      change manage_relationship(:device_id, :device,
               type: :append,
               eager_validate_with: Edgehog.Devices
             )

      change set_attribute(:manual?, true)
      change Changes.HandleEphemeralImageUpload
      change Changes.SendUpdateRequest
    end

    destroy :destroy do
      require_atomic? false

      change Changes.HandleEphemeralImageDeletion do
        where attribute_equals(:manual?, true)
      end
    end

    update :mark_as_timed_out do
      # Needed because HandleEphemeralImageDeletion are not atomic
      require_atomic? false

      change set_attribute(:status, :failure)
      change set_attribute(:status_code, :request_timeout)

      change Changes.HandleEphemeralImageDeletion do
        where attribute_equals(:manual?, true)
      end

      change Changes.LogOtaOperationOutcome do
        where [attribute_in(:status, @terminal_statuses)]
      end
    end

    update :update_status do
      accept [:status, :status_progress, :status_code, :message]

      # Needed because and HandleEphemeralImageDeletion are not atomic
      require_atomic? false

      change Changes.HandleEphemeralImageDeletion do
        where [attribute_equals(:manual?, true), attribute_in(:status, @terminal_statuses)]
      end

      change Changes.LogOtaOperationOutcome do
        where [attribute_in(:status, @terminal_statuses)]
      end
    end

    action :send_update_request do
      argument :ota_operation, :struct do
        constraints instance_of: __MODULE__
        allow_nil? false
      end

      run ManualActions.SendUpdateRequest
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :base_image_url, :string do
      public? true
      description "The URL of the base image being installed on the device"
      allow_nil? false
    end

    attribute :status, Status do
      public? true
      description "The current status of the operation"
      default :pending
      allow_nil? false
    end

    attribute :status_progress, :integer do
      constraints min: 0, max: 100
      public? true
      description "The percentage progress [0-100] for the current status"
      default 0
      allow_nil? false
    end

    attribute :status_code, StatusCode do
      public? true
      description "The current status code of the operation"
    end

    attribute :message, :string do
      public? true
      description "A message with additional details about the current status"
    end

    attribute :manual?, :boolean do
      default false
      source :is_manual
    end

    create_timestamp :inserted_at do
      description "The creation timestamp of the operation"
      public? true
    end

    update_timestamp :updated_at do
      description "The timestamp of the last update to the operation"
      public? true
    end
  end

  relationships do
    belongs_to :device, Edgehog.Devices.Device do
      description "The device targeted from the operation"
      public? true
      attribute_public? false
      allow_nil? false
    end

    has_one :update_target, Edgehog.UpdateCampaigns.UpdateTarget do
      description """
      The update target of an update campaing that created the managed
      ota operation, if any.
      """

      public? true
    end
  end

  calculations do
    calculate :finished?, :boolean, expr(status == :success or status == :failure)
  end

  pub_sub do
    prefix "ota_operations"
    module EdgehogWeb.Endpoint

    publish :create_managed, [[:id, "*"]]
    publish :manual, [[:id, "*"]]
    publish :mark_as_timed_out, [[:id, "*"]]
    publish :update_status, [[:id, "*"]]

    transform fn notification ->
      ota_operation = notification.data
      action = notification.action.name

      event_type =
        cond do
          action in [:create_managed, :manual] ->
            :ota_operation_created

          action in [
            :mark_as_timed_out,
            :update_status
          ] ->
            :ota_operation_updated

          true ->
            :unknown_event
        end

      {event_type, ota_operation}
    end
  end

  postgres do
    table "ota_operations"
    repo Edgehog.Repo

    references do
      reference :device,
        index?: true,
        on_delete: :nothing,
        match_type: :full,
        match_with: [tenant_id: :tenant_id]
    end
  end
end
