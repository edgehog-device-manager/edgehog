#
# This file is part of Edgehog.
#
# Copyright 2021 - 2025 SECO Mind Srl
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

Mox.defmock(Edgehog.Astarte.Device.DeviceStatusMock,
  for: Edgehog.Astarte.Device.DeviceStatus.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.BaseImageMock,
  for: Edgehog.Astarte.Device.BaseImage.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.HardwareInfoMock,
  for: Edgehog.Astarte.Device.HardwareInfo.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.OSInfoMock,
  for: Edgehog.Astarte.Device.OSInfo.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.OTARequestV1Mock,
  for: Edgehog.Astarte.Device.OTARequest.V1.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.StorageUsageMock,
  for: Edgehog.Astarte.Device.StorageUsage.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.SystemStatusMock,
  for: Edgehog.Astarte.Device.SystemStatus.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.GeolocationMock,
  for: Edgehog.Astarte.Device.Geolocation.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.WiFiScanResultMock,
  for: Edgehog.Astarte.Device.WiFiScanResult.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.BatteryStatusMock,
  for: Edgehog.Astarte.Device.BatteryStatus.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.CellularConnectionMock,
  for: Edgehog.Astarte.Device.CellularConnection.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.RuntimeInfoMock,
  for: Edgehog.Astarte.Device.RuntimeInfo.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.NetworkInterfaceMock,
  for: Edgehog.Astarte.Device.NetworkInterface.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.LedBehaviorMock,
  for: Edgehog.Astarte.Device.LedBehavior.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.ForwarderSessionMock,
  for: Edgehog.Astarte.Device.ForwarderSession.Behaviour
)

Mox.defmock(Edgehog.Astarte.Interface.MockDataLayer,
  for: Edgehog.Astarte.Interface.DataLayer
)

Mox.defmock(Edgehog.Astarte.DeliveryPolicies.MockDataLayer,
  for: Edgehog.Astarte.DeliveryPolicies.DataLayer
)

Mox.defmock(Edgehog.Astarte.Trigger.MockDataLayer,
  for: Edgehog.Astarte.Trigger.DataLayer
)

Mox.defmock(Edgehog.Assets.SystemModelPictureMock, for: Edgehog.Assets.Store.Behaviour)

Mox.defmock(Edgehog.OSManagement.EphemeralImageMock,
  for: Edgehog.OSManagement.EphemeralImage.Behaviour
)

Mox.defmock(Edgehog.BaseImages.StorageMock, for: Edgehog.BaseImages.Storage)

Mox.defmock(Edgehog.Tenants.ReconcilerMock, for: Edgehog.Tenants.Reconciler.Behaviour)
