/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

import { FragmentRefs } from "relay-runtime";
export type Device_getDevice_QueryVariables = {
    id: string;
};
export type Device_getDevice_QueryResponse = {
    readonly device: {
        readonly id: string;
        readonly deviceId: string;
        readonly lastConnection: string | null;
        readonly lastDisconnection: string | null;
        readonly name: string;
        readonly online: boolean;
        readonly applianceModel: {
            readonly name: string;
            readonly pictureUrl: string | null;
            readonly hardwareType: {
                readonly name: string;
            };
        } | null;
        readonly " $fragmentRefs": FragmentRefs<"Device_hardwareInfo" | "Device_osInfo" | "Device_location" | "Device_storageUsage" | "Device_systemStatus" | "Device_wifiScanResults" | "Device_batteryStatus">;
    } | null;
};
export type Device_getDevice_Query = {
    readonly response: Device_getDevice_QueryResponse;
    readonly variables: Device_getDevice_QueryVariables;
};



/*
query Device_getDevice_Query(
  $id: ID!
) {
  device(id: $id) {
    id
    deviceId
    lastConnection
    lastDisconnection
    name
    online
    applianceModel {
      name
      pictureUrl
      hardwareType {
        name
        id
      }
      id
    }
    ...Device_hardwareInfo
    ...Device_osInfo
    ...Device_location
    ...Device_storageUsage
    ...Device_systemStatus
    ...Device_wifiScanResults
    ...Device_batteryStatus
  }
}

fragment Device_batteryStatus on Device {
  batteryStatus {
    slot
    status
    levelPercentage
    levelAbsoluteError
  }
}

fragment Device_hardwareInfo on Device {
  hardwareInfo {
    cpuArchitecture
    cpuModel
    cpuModelName
    cpuVendor
    memoryTotalBytes
  }
}

fragment Device_location on Device {
  location {
    latitude
    longitude
    accuracy
    address
    timestamp
  }
}

fragment Device_osInfo on Device {
  osInfo {
    name
    version
  }
}

fragment Device_storageUsage on Device {
  storageUsage {
    label
    totalBytes
    freeBytes
  }
}

fragment Device_systemStatus on Device {
  systemStatus {
    memoryFreeBytes
    taskCount
    uptimeMilliseconds
    timestamp
  }
}

fragment Device_wifiScanResults on Device {
  wifiScanResults {
    channel
    essid
    macAddress
    rssi
    timestamp
  }
}
*/

const node: ConcreteRequest = (function(){
var v0 = [
  {
    "defaultValue": null,
    "kind": "LocalArgument",
    "name": "id"
  }
],
v1 = [
  {
    "kind": "Variable",
    "name": "id",
    "variableName": "id"
  }
],
v2 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "id",
  "storageKey": null
},
v3 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "deviceId",
  "storageKey": null
},
v4 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "lastConnection",
  "storageKey": null
},
v5 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "lastDisconnection",
  "storageKey": null
},
v6 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "name",
  "storageKey": null
},
v7 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "online",
  "storageKey": null
},
v8 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "pictureUrl",
  "storageKey": null
},
v9 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "timestamp",
  "storageKey": null
};
return {
  "fragment": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Fragment",
    "metadata": null,
    "name": "Device_getDevice_Query",
    "selections": [
      {
        "alias": null,
        "args": (v1/*: any*/),
        "concreteType": "Device",
        "kind": "LinkedField",
        "name": "device",
        "plural": false,
        "selections": [
          (v2/*: any*/),
          (v3/*: any*/),
          (v4/*: any*/),
          (v5/*: any*/),
          (v6/*: any*/),
          (v7/*: any*/),
          {
            "alias": null,
            "args": null,
            "concreteType": "ApplianceModel",
            "kind": "LinkedField",
            "name": "applianceModel",
            "plural": false,
            "selections": [
              (v6/*: any*/),
              (v8/*: any*/),
              {
                "alias": null,
                "args": null,
                "concreteType": "HardwareType",
                "kind": "LinkedField",
                "name": "hardwareType",
                "plural": false,
                "selections": [
                  (v6/*: any*/)
                ],
                "storageKey": null
              }
            ],
            "storageKey": null
          },
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "Device_hardwareInfo"
          },
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "Device_osInfo"
          },
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "Device_location"
          },
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "Device_storageUsage"
          },
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "Device_systemStatus"
          },
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "Device_wifiScanResults"
          },
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "Device_batteryStatus"
          }
        ],
        "storageKey": null
      }
    ],
    "type": "RootQueryType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "Device_getDevice_Query",
    "selections": [
      {
        "alias": null,
        "args": (v1/*: any*/),
        "concreteType": "Device",
        "kind": "LinkedField",
        "name": "device",
        "plural": false,
        "selections": [
          (v2/*: any*/),
          (v3/*: any*/),
          (v4/*: any*/),
          (v5/*: any*/),
          (v6/*: any*/),
          (v7/*: any*/),
          {
            "alias": null,
            "args": null,
            "concreteType": "ApplianceModel",
            "kind": "LinkedField",
            "name": "applianceModel",
            "plural": false,
            "selections": [
              (v6/*: any*/),
              (v8/*: any*/),
              {
                "alias": null,
                "args": null,
                "concreteType": "HardwareType",
                "kind": "LinkedField",
                "name": "hardwareType",
                "plural": false,
                "selections": [
                  (v6/*: any*/),
                  (v2/*: any*/)
                ],
                "storageKey": null
              },
              (v2/*: any*/)
            ],
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "concreteType": "HardwareInfo",
            "kind": "LinkedField",
            "name": "hardwareInfo",
            "plural": false,
            "selections": [
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "cpuArchitecture",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "cpuModel",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "cpuModelName",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "cpuVendor",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "memoryTotalBytes",
                "storageKey": null
              }
            ],
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "concreteType": "OsInfo",
            "kind": "LinkedField",
            "name": "osInfo",
            "plural": false,
            "selections": [
              (v6/*: any*/),
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "version",
                "storageKey": null
              }
            ],
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "concreteType": "DeviceLocation",
            "kind": "LinkedField",
            "name": "location",
            "plural": false,
            "selections": [
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "latitude",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "longitude",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "accuracy",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "address",
                "storageKey": null
              },
              (v9/*: any*/)
            ],
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "concreteType": "StorageUnit",
            "kind": "LinkedField",
            "name": "storageUsage",
            "plural": true,
            "selections": [
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "label",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "totalBytes",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "freeBytes",
                "storageKey": null
              }
            ],
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "concreteType": "SystemStatus",
            "kind": "LinkedField",
            "name": "systemStatus",
            "plural": false,
            "selections": [
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "memoryFreeBytes",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "taskCount",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "uptimeMilliseconds",
                "storageKey": null
              },
              (v9/*: any*/)
            ],
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "concreteType": "WifiScanResult",
            "kind": "LinkedField",
            "name": "wifiScanResults",
            "plural": true,
            "selections": [
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "channel",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "essid",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "macAddress",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "rssi",
                "storageKey": null
              },
              (v9/*: any*/)
            ],
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "concreteType": "BatterySlot",
            "kind": "LinkedField",
            "name": "batteryStatus",
            "plural": true,
            "selections": [
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "slot",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "status",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "levelPercentage",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "levelAbsoluteError",
                "storageKey": null
              }
            ],
            "storageKey": null
          }
        ],
        "storageKey": null
      }
    ]
  },
  "params": {
    "cacheID": "d68f40447adece0c5e2959b8d9011493",
    "id": null,
    "metadata": {},
    "name": "Device_getDevice_Query",
    "operationKind": "query",
    "text": "query Device_getDevice_Query(\n  $id: ID!\n) {\n  device(id: $id) {\n    id\n    deviceId\n    lastConnection\n    lastDisconnection\n    name\n    online\n    applianceModel {\n      name\n      pictureUrl\n      hardwareType {\n        name\n        id\n      }\n      id\n    }\n    ...Device_hardwareInfo\n    ...Device_osInfo\n    ...Device_location\n    ...Device_storageUsage\n    ...Device_systemStatus\n    ...Device_wifiScanResults\n    ...Device_batteryStatus\n  }\n}\n\nfragment Device_batteryStatus on Device {\n  batteryStatus {\n    slot\n    status\n    levelPercentage\n    levelAbsoluteError\n  }\n}\n\nfragment Device_hardwareInfo on Device {\n  hardwareInfo {\n    cpuArchitecture\n    cpuModel\n    cpuModelName\n    cpuVendor\n    memoryTotalBytes\n  }\n}\n\nfragment Device_location on Device {\n  location {\n    latitude\n    longitude\n    accuracy\n    address\n    timestamp\n  }\n}\n\nfragment Device_osInfo on Device {\n  osInfo {\n    name\n    version\n  }\n}\n\nfragment Device_storageUsage on Device {\n  storageUsage {\n    label\n    totalBytes\n    freeBytes\n  }\n}\n\nfragment Device_systemStatus on Device {\n  systemStatus {\n    memoryFreeBytes\n    taskCount\n    uptimeMilliseconds\n    timestamp\n  }\n}\n\nfragment Device_wifiScanResults on Device {\n  wifiScanResults {\n    channel\n    essid\n    macAddress\n    rssi\n    timestamp\n  }\n}\n"
  }
};
})();
(node as any).hash = '1083036c1d2103eb2bf70bc1a08b7528';
export default node;
