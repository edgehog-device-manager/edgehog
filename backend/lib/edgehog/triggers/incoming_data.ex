# This file is part of Edgehog.
#
# Copyright 2024, 2026 SECO Mind Srl
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

defmodule Edgehog.Triggers.IncomingData do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [Ash.Astarte.Triggers.Resource]

  alias Edgehog.Triggers.IncomingData.Handlers.AvailableContainers
  alias Edgehog.Triggers.IncomingData.Handlers.AvailableDeployments
  alias Edgehog.Triggers.IncomingData.Handlers.AvailableDeviceMappings
  alias Edgehog.Triggers.IncomingData.Handlers.AvailableImages
  alias Edgehog.Triggers.IncomingData.Handlers.AvailableNetworks
  alias Edgehog.Triggers.IncomingData.Handlers.AvailableVolumes
  alias Edgehog.Triggers.IncomingData.Handlers.DeploymentEvent
  alias Edgehog.Triggers.IncomingData.Handlers.FileStorage
  alias Edgehog.Triggers.IncomingData.Handlers.FileTransfer
  alias Edgehog.Triggers.IncomingData.Handlers.OTAEvent
  alias Edgehog.Triggers.IncomingData.Handlers.OTAResponse
  alias Edgehog.Triggers.IncomingData.Handlers.SystemInfo

  handlers do
    handler AvailableImages do
      filter interface: "io.edgehog.devicemanager.apps.AvailableImages"
    end

    handler AvailableNetworks do
      filter interface: "io.edgehog.devicemanager.apps.AvailableNetworks"
    end

    handler AvailableVolumes do
      filter interface: "io.edgehog.devicemanager.apps.AvailableVolumes"
    end

    handler AvailableDeviceMappings do
      filter interface: "io.edgehog.devicemanager.apps.AvailableDeviceMappings"
    end

    handler AvailableContainers do
      filter interface: "io.edgehog.devicemanager.apps.AvailableContainers"
    end

    handler AvailableDeployments do
      filter interface: "io.edgehog.devicemanager.apps.AvailableDeployments"
    end

    handler DeploymentEvent do
      filter interface: "io.edgehog.devicemanager.apps.DeploymentEvent"
    end

    handler OTAEvent do
      filter interface: "io.edgehog.devicemanager.OTAEvent"
    end

    handler OTAResponse do
      filter interface: "io.edgehog.devicemanager.OTAResponse"
    end

    handler SystemInfo do
      filter interface: "io.edgehog.devicemanager.SystemInfo"
    end

    handler FileStorage do
      filter interface: "io.edgehog.devicemanager.storage.File"
    end

    handler FileTransfer.Response do
      filter interface: "io.edgehog.devicemanager.fileTransfer.Response"
    end

    handler FileTransfer.Progress do
      filter interface: "io.edgehog.devicemanager.fileTransfer.Progress"
    end

    handler Edgehog.Triggers.Handlers.Fallback
  end

  astarte do
    tag :incoming_data
  end

  attributes do
    attribute :interface, :string do
      public? true
      allow_nil? false
    end

    attribute :path, :string do
      public? true
      allow_nil? false
    end

    attribute :value, :term do
      public? true
    end
  end
end
