/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import { MockPayloadGenerator } from "relay-test-utils";

import assets from "assets";

const relayMockResolvers: MockPayloadGenerator.MockResolvers = {
  SystemModel() {
    return {
      handle: "esp32-dev-kit-c",
      name: "ESP32-DevKitC",
      partNumbers: ["AM_0000001"],
      pictureUrl: assets.images.brand,
    };
  },
  BatterySlot() {
    return {
      levelAbsoluteError: 0.1,
      levelPercentage: 80.3,
      slot: "Slot identifier",
      status: "CHARGING",
    };
  },
  Device() {
    return {
      deviceId: "DqL4H107S42WBEHmDrvPLQ",
      id: "1",
      name: "Thingie",
    };
  },
  HardwareInfo() {
    return {
      cpuArchitecture: "Xtensa 32-bit",
      cpuModel: "ESP32-C3",
      cpuModelName: "ESP32-DevKitC",
      cpuVendor: "Espressif",
      memoryTotalBytes: 409600,
    };
  },
  HardwareType() {
    return {
      handle: "esp32",
      name: "ESP32",
      partNumbers: ["HT_0000001"],
    };
  },
  DeviceLocation() {
    return {
      latitude: 45.463,
      longitude: 9.188,
      accuracy: 10,
      address: "Via Speronari, 7, 20123 Milano MI",
      timestamp: "2021-11-11T09:43:54.437Z",
    };
  },
  OsBundle() {
    return {
      name: "FreeRTOS",
      version: "10.4.3",
      buildId: "2022-01-01 12:00:00",
      fingerprint:
        "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3",
    };
  },
  OsInfo() {
    return {
      name: "FreeRTOS",
      version: "v10.4.3",
    };
  },
  StorageUnit() {
    return {
      label: "Disk 0",
      totalBytes: 268435456,
      freeBytes: 128435456,
    };
  },
  SystemStatus() {
    return {
      bootId: "1c0cf72f-8428-4838-8626-1a748df5b889",
      memoryFreeBytes: 166772,
      taskCount: 12,
      uptimeMilliseconds: 5785,
      timestamp: "2021-11-15T11:44:57.432Z",
    };
  },
  WifiScanResult() {
    return {
      channel: 1,
      essid: "MyWifi",
      macAddress: "00:11:22:33:44:55",
      rssi: -50,
      timestamp: "2021-11-16T10:43:54.437Z",
    };
  },
};

export { relayMockResolvers };
