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
schema: '1.2'
contents:
  - model/core.fga
  - model/tenancy.fga
  - model/device_management/realm.fga
  - model/device_management/device.fga
  - model/device_management/hardware_type.fga
  - model/device_management/system_model.fga
  - model/os_management/base_image.fga
  - model/os_management/base_image_collection.fga
  - model/campaigns/device_group.fga
  - model/campaigns/channel.fga
  - model/campaigns/campaign.fga
  - model/campaigns/firmware_update_campaigns.fga
  - model/campaigns/deployment_campaigns.fga
  - model/campaigns/deployment_campaigns/provision.fga
  - model/campaigns/deployment_campaigns/start.fga
  - model/campaigns/deployment_campaigns/stop.fga
  - model/campaigns/deployment_campaigns/update.fga
  - model/campaigns/deployment_campaigns/delete.fga
  - model/container_management/image_credentials.fga
  - model/container_management/network.fga
  - model/container_management/volume.fga
  - model/container_management/container.fga
  - model/container_management/release.fga
  - model/container_management/application.fga
  - model/container_management/deployment.fga
