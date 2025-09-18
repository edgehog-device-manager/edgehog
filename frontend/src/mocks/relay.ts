/*
  This file is part of Edgehog.

  Copyright 2021-2024 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import { MockPayloadGenerator } from "relay-test-utils";

import assets from "assets";

const relayMockResolvers: MockPayloadGenerator.MockResolvers = {
  SystemModel(_, generateId) {
    const id = generateId();
    return {
      id: btoa(`SystemModel:${id}`),
      handle: "esp32-dev-kit-c",
      name: "ESP32-DevKitC",
      partNumbers: ["AM_0000001"],
      pictureUrl: assets.images.brand,
    };
  },
  BaseImage(_, generateId) {
    const id = generateId();
    return {
      id: btoa(`BaseImage:${id}`),
      description: "Base Image Description",
      releaseDisplayName: "release-1",
      startingVersionRequirement: null,
      url: "https://sample-storage.com/bucket/base_images/1.0.0.bin",
      version: "1.0.0",
    };
  },
  BaseImageCollection(_, generateId) {
    const id = generateId();
    return {
      id: btoa(`BaseImageCollection:${id}`),
      handle: `base-image-collection-${id}`,
      name: `Base Image Collection ${id}`,
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
  Device(_, generateId) {
    const id = generateId();
    return {
      id: btoa(`Device:${id}`),
      deviceId: "DqL4H107S42WBEHmDrvPLQ",
      name: "Thingie",
      capabilities: [
        "HARDWARE_INFO",
        "BASE_IMAGE",
        "OPERATING_SYSTEM",
        "RUNTIME_INFO",
        "STORAGE",
        "GEOLOCATION",
        "SYSTEM_STATUS",
        "WIFI",
        "BATTERY_STATUS",
        "SOFTWARE_UPDATES",
        "CELLULAR_CONNECTION",
        "LED_BEHAVIORS",
      ],
      tags: ["foo", "bar"],
    };
  },
  DeviceGroup(_, generateId) {
    const id = generateId();
    return {
      id: btoa(`DeviceGroup:${id}`),
      name: "Tags: foo",
      handle: "tags-foo",
      selector: '"foo" in tags',
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
  HardwareType(_, generateId) {
    const id = generateId();
    return {
      id: btoa(`HardwareType:${id}`),
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
  BaseImageInfo() {
    return {
      name: "FreeRTOS",
      version: "10.4.3",
      buildId: "2022-01-01 12:00:00",
      fingerprint:
        "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3",
    };
  },
  Modem() {
    return {
      apn: "company.com",
      carrier: "Carrier",
      cellId: 170402199,
      imei: "509504877678976",
      imsi: "313460000000001",
      localAreaCode: 35632,
      mobileCountryCode: 310,
      mobileNetworkCode: 410,
      registrationStatus: "REGISTERED",
      rssi: -60,
      slot: "modem_1",
      technology: "GSM",
    };
  },
  NetworkInterface() {
    return {
      name: "enp2s0",
      macAddress: "00:aa:bb:cc:dd:ee",
      technology: "ETHERNET",
    };
  },
  OsInfo() {
    return {
      name: "FreeRTOS",
      version: "v10.4.3",
    };
  },
  RuntimeInfo() {
    return {
      name: "edgehog-esp32-device",
      version: "0.1.0",
      environment: "esp-idf v4.3",
      url: "https://github.com/edgehog-device-manager/edgehog-esp32-device",
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
  Channel(_, generateId) {
    const id = generateId();
    return {
      id: btoa(`UpdateChannel:${id}`),
      name: "Foo devices",
      handle: "channel-foo",
    };
  },
  UpdateCampaign(_, generateId) {
    const id = generateId();
    return {
      id: btoa(`UpdateCampaign:${id}`),
      name: `Update Campaign ${id}`,
      status: "IN_PROGRESS",
      outcome: null,
      rolloutMechanism: {
        maxFailurePercentage: 5,
        maxInProgressUpdates: 2,
        otaRequestRetries: 10,
        otaRequestTimeoutSeconds: 120,
        forceDowngrade: false,
      },
    };
  },
  UpdateTarget(_, generateId) {
    return {
      id: btoa(`UpdateTarget:${generateId()}`),
      status: "PENDING",
    };
  },
  WifiScanResult() {
    return {
      channel: 1,
      connected: true,
      essid: "MyWifi",
      macAddress: "00:11:22:33:44:55",
      rssi: -50,
      timestamp: "2021-11-16T10:43:54.437Z",
    };
  },
};

export { relayMockResolvers };
