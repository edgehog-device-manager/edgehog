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

defmodule Edgehog.Devices do
  @moduledoc """
  The Devices context.
  """

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  graphql do
    root_level_errors? true

    queries do
      get Edgehog.Devices.Device, :device, :read do
        description "Returns a single device."
      end

      list Edgehog.Devices.Device, :devices, :read do
        description "Returns a list of devices."
        paginate_with nil
      end

      get Edgehog.Devices.HardwareType, :hardware_type, :read do
        description "Returns a single hardware type."
      end

      list Edgehog.Devices.HardwareType, :hardware_types, :read do
        description "Returns a list of hardware types."
        paginate_with nil
      end

      get Edgehog.Devices.SystemModel, :system_model, :read do
        description "Returns a single system model."
      end

      list Edgehog.Devices.SystemModel, :system_models, :read do
        description "Returns a list of system models."
        paginate_with nil
      end
    end

    mutations do
      update Edgehog.Devices.Device, :update_device, :update
      update Edgehog.Devices.Device, :add_device_tags, :add_tags
      update Edgehog.Devices.Device, :remove_device_tags, :remove_tags
      update Edgehog.Devices.Device, :set_device_led_behavior, :set_led_behavior
      create Edgehog.Devices.HardwareType, :create_hardware_type, :create
      update Edgehog.Devices.HardwareType, :update_hardware_type, :update
      destroy Edgehog.Devices.HardwareType, :delete_hardware_type, :destroy

      create Edgehog.Devices.SystemModel, :create_system_model, :create do
        relay_id_translations input: [hardware_type_id: :hardware_type]
      end

      update Edgehog.Devices.SystemModel, :update_system_model, :update
      destroy Edgehog.Devices.SystemModel, :delete_system_model, :destroy
    end
  end

  resources do
    resource Edgehog.Devices.Device
    resource Edgehog.Devices.HardwareType
    resource Edgehog.Devices.HardwareTypePartNumber
    resource Edgehog.Devices.SystemModel
    resource Edgehog.Devices.SystemModelPartNumber
  end
end
