#
# This file is part of Edgehog.
#
# Copyright 2021-2026 SECO Mind Srl
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

ExUnit.start(exclude: [:integration_storage, :integration_openfga], capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Edgehog.Repo, :manual)

# Mimics

Mimic.copy(Edgehog.Geolocation.Providers.TestGeolocation)
Mimic.copy(Edgehog.Geolocation.Providers.TestGeocoding)
Mimic.copy(Edgehog.Auth.FGAService)
Mimic.copy(Openfga.V1.OpenFGAService.Stub)
Mimic.copy(GRPC.Stub)
Mimic.copy(Edgehog.Astarte.Device.CreateContainerRequest)
Mimic.copy(Edgehog.Astarte.Device.CreateDeploymentRequest)
Mimic.copy(Edgehog.Astarte.Device.CreateDeviceMappingRequest)
Mimic.copy(Edgehog.Astarte.Device.CreateImageRequest)
Mimic.copy(Edgehog.Astarte.Device.CreateNetworkRequest)
Mimic.copy(Edgehog.Astarte.Device.CreateVolumeRequest)

Mimic.copy(Edgehog.Astarte.Device.DeviceStatus)
Mimic.copy(Edgehog.Astarte.Device.BaseImage)
Mimic.copy(Edgehog.Astarte.Device.HardwareInfo)
Mimic.copy(Edgehog.Astarte.Device.OSInfo)
Mimic.copy(Edgehog.Astarte.Device.OTARequest.V1)
Mimic.copy(Edgehog.Astarte.Device.StorageUsage)
Mimic.copy(Edgehog.Astarte.Device.DeploymentCommand)
Mimic.copy(Edgehog.Astarte.Device.DeploymentUpdate)
Mimic.copy(Edgehog.Astarte.Device.AvailableContainers)
Mimic.copy(Edgehog.Astarte.Device.CreateContainerRequest)
Mimic.copy(Edgehog.Astarte.Device.CreateDeploymentRequest)
Mimic.copy(Edgehog.Astarte.Device.CreateNetworkRequest)
Mimic.copy(Edgehog.Astarte.Device.CreateDeviceMappingRequest)
Mimic.copy(Edgehog.Astarte.Device.CreateDeviceRequestRequest)
Mimic.copy(Edgehog.Astarte.Device.CreateImageRequest)
Mimic.copy(Edgehog.Astarte.Device.CreateVolumeRequest)
Mimic.copy(Edgehog.Astarte.Device.SystemStatus)
Mimic.copy(Edgehog.Astarte.Device.Geolocation)
Mimic.copy(Edgehog.Astarte.Device.WiFiScanResult)
Mimic.copy(Edgehog.Astarte.Device.BatteryStatus)
Mimic.copy(Edgehog.Astarte.Device.CellularConnection)
Mimic.copy(Edgehog.Astarte.Device.RuntimeInfo)
Mimic.copy(Edgehog.Astarte.Device.NetworkInterface)
Mimic.copy(Edgehog.Astarte.Device.LedBehavior)
Mimic.copy(Edgehog.Astarte.Device.ForwarderSession)
Mimic.copy(Edgehog.Astarte.Interface.AstarteDataLayer)
Mimic.copy(Edgehog.Astarte.DeliveryPolicies.AstarteDataLayer)
Mimic.copy(Edgehog.Astarte.Trigger.AstarteDataLayer)
Mimic.copy(Edgehog.Assets.SystemModelPicture)
Mimic.copy(Edgehog.OSManagement.EphemeralImage)
Mimic.copy(Edgehog.Files.EphemeralFile)
Mimic.copy(Edgehog.BaseImages.BucketStorage)
Mimic.copy(Edgehog.Tenants.Reconciler)
Mimic.copy(Edgehog.Containers.Reconciler)
Mimic.copy(Edgehog.Astarte.Device.FileDownloadRequest)
Mimic.copy(Edgehog.Astarte.Device.FileUploadRequest)
Mimic.copy(Edgehog.Astarte.Device.FileDeleteRequest)
Mimic.copy(Edgehog.Astarte.Device.FileTransferCapabilities)
Mimic.copy(Edgehog.Astarte.Device.AvailableImages)
Mimic.copy(Edgehog.Astarte.Device.AvailableDeployments)
Mimic.copy(Edgehog.Astarte.Device.AvailableVolumes)
Mimic.copy(Edgehog.Astarte.Device.AvailableNetworks)
Mimic.copy(Edgehog.Astarte.Device.AvailableDeviceMappings)
Mimic.copy(Edgehog.Astarte.Device.AvailableDevices)
Mimic.copy(Edgehog.Storage)
Mimic.copy(Edgehog.Files.File.BucketStorage)
Mimic.copy(Edgehog.Containers.Image.Deployment.Provisioner)
Mimic.copy(Edgehog.Containers.Network.Deployment.Provisioner)
Mimic.copy(Edgehog.Containers.DeviceMapping.Deployment.Provisioner)
Mimic.copy(Edgehog.Containers.Volume.Deployment.Provisioner)
Mimic.copy(Edgehog.Containers.DeviceRequest.Deployment.Provisioner)
Mimic.copy(Edgehog.Containers.Container.Deployment.Provisioner)
Mimic.copy(Edgehog.Containers.Container.Deployment.Supervisor)
