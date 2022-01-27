#
# This file is part of Edgehog.
#
# Copyright 2021-2022 SECO Mind Srl
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

Mox.defmock(Edgehog.Astarte.Device.DeviceStatusMock,
  for: Edgehog.Astarte.Device.DeviceStatus.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.BaseImageMock,
  for: Edgehog.Astarte.Device.BaseImage.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.OSInfoMock,
  for: Edgehog.Astarte.Device.OSInfo.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.OTARequestMock,
  for: Edgehog.Astarte.Device.OTARequest.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.StorageUsageMock,
  for: Edgehog.Astarte.Device.StorageUsage.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.SystemStatusMock,
  for: Edgehog.Astarte.Device.SystemStatus.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.WiFiScanResultMock,
  for: Edgehog.Astarte.Device.WiFiScanResult.Behaviour
)

Mox.defmock(Edgehog.Astarte.Device.BatteryStatusMock,
  for: Edgehog.Astarte.Device.BatteryStatus.Behaviour
)

Mox.defmock(Edgehog.Geolocation.IPGeolocationProviderMock,
  for: Edgehog.Geolocation.IPGeolocationProvider
)

Mox.defmock(Edgehog.Geolocation.WiFiGeolocationProviderMock,
  for: Edgehog.Geolocation.WiFiGeolocationProvider
)

Mox.defmock(Edgehog.Geolocation.GeocodingProviderMock, for: Edgehog.Geolocation.GeocodingProvider)

Mox.defmock(Edgehog.Assets.SystemModelPictureMock, for: Edgehog.Assets.Store.Behaviour)

Mox.defmock(Edgehog.OSManagement.EphemeralImageMock,
  for: Edgehog.OSManagement.EphemeralImage.Behaviour
)
