import { MockPayloadGenerator } from "relay-test-utils";

const relayMockResolvers: MockPayloadGenerator.MockResolvers = {
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
};

export { relayMockResolvers };
