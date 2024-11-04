#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.AstarteTypes do
  @moduledoc false
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  @desc """
  Describes hardware-related info of a device.

  It exposes data read by a device's operating system about the underlying \
  hardware.
  """
  object :hardware_info do
    @desc "The architecture of the CPU."
    field :cpu_architecture, :string

    @desc "The reference code of the CPU model."
    field :cpu_model, :string

    @desc "The display name of the CPU model."
    field :cpu_model_name, :string

    @desc "The vendor's name."
    field :cpu_vendor, :string

    @desc "The Bytes count of memory."
    field :memory_total_bytes, :integer
  end

  @desc "Describes the current usage of a storage unit on a device."
  object :storage_unit do
    @desc "The label of the storage unit."
    field :label, non_null(:string)

    @desc "The total number of bytes of the storage unit."
    field :total_bytes, :integer

    @desc "The number of free bytes of the storage unit."
    field :free_bytes, :integer
  end

  @desc "Describes the information on the system's base image for a device."
  object :base_image_info do
    @desc "The name of the image."
    field :name, :string

    @desc "The version of the image."
    field :version, :string

    @desc "Human readable build identifier of the image."
    field :build_id, :string

    @desc """
    A unique string that identifies the release, usually the image hash.
    """
    field :fingerprint, :string
  end

  @desc "Describes an operating system of a device."
  object :os_info do
    @desc "The name of the operating system."
    field :name, :string

    @desc "The version of the operating system."
    field :version, :string
  end

  @desc """
  Describes the current status of the operating system of a device.
  """
  object :system_status do
    @desc "The identifier of the performed boot sequence."
    field :boot_id, :string

    @desc "The number of free bytes of memory."
    field :memory_free_bytes, :integer

    @desc "The number of running tasks on the system."
    field :task_count, :integer

    @desc "The number of milliseconds since the last system boot."
    field :uptime_milliseconds, :integer

    @desc "The date at which the system status was read."
    field :timestamp, non_null(:datetime)
  end

  @desc """
  Describes the list of WiFi Access Points found by the device.
  """
  object :wifi_scan_result do
    @desc "The channel used by the Access Point."
    field :channel, :integer

    @desc "Indicates whether the device is connected to the Access Point."
    field :connected, :boolean

    @desc "The ESSID advertised by the Access Point."
    field :essid, :string

    @desc "The MAC address advertised by the Access Point."
    field :mac_address, :string

    @desc "The power of the radio signal, measured in dBm."
    field :rssi, :integer

    @desc "The date at which the device found the Access Point."
    field :timestamp, non_null(:datetime)
  end

  @desc "Describes the status of a container on a device."
  object :container_status do
    @desc "The identifier of the container."
    field :id, :string

    @desc "The status of the container."
    field :status, :string
  end

  @desc "Describes an Edgehog runtime."
  object :runtime_info do
    @desc "The name of the Edgehog runtime."
    field :name, :string

    @desc "The version of the Edgehog runtime."
    field :version, :string

    @desc "The environment of the Edgehog runtime."
    field :environment, :string

    @desc "The URL that uniquely identifies the Edgehog runtime implementation."
    field :url, :string
  end

  @desc "Describe the available images on the device."
  object :image_status do
    @desc "The image id."
    field :id, :string

    @desc "Whether the image is pulled or not."
    field :pulled, :boolean
  end

  @desc "Describes the status of a deployment on a device."
  object :deployment_status do
    @desc "The deployment id."
    field :id, :string

    @desc "The deployment status, can be :idle, :starting, :started, :stopping, :stopped or :error"
    field :status, :string
  end

  @desc "Describes the status of a volume on a device."
  object :volume_status do
    @desc "The volume id."
    field :id, :string

    @desc "The volume status, wheather it was created or not."
    field :created, :boolean
  end
end
