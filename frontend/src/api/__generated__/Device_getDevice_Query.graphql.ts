/**
 * @generated SignedSource<<ee9c3cb005f8a2ee83ec575ce3ede2a0>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Query } from 'relay-runtime';
import { FragmentRefs } from "relay-runtime";
export type Device_getDevice_Query$variables = {
  id: string;
};
export type Device_getDevice_Query$data = {
  readonly device: {
    readonly id: string;
    readonly deviceId: string;
    readonly lastConnection: string | null;
    readonly lastDisconnection: string | null;
    readonly name: string;
    readonly online: boolean;
    readonly systemModel: {
      readonly name: string;
      readonly pictureUrl: string | null;
      readonly hardwareType: {
        readonly name: string;
      };
    } | null;
    readonly cellularConnection: ReadonlyArray<{
      readonly __typename: string;
    }> | null;
    readonly " $fragmentSpreads": FragmentRefs<"Device_hardwareInfo" | "Device_baseImage" | "Device_osInfo" | "Device_runtimeInfo" | "Device_location" | "Device_storageUsage" | "Device_systemStatus" | "Device_wifiScanResults" | "Device_batteryStatus" | "Device_otaOperations" | "CellularConnectionTabs_cellularConnection">;
  } | null;
};
export type Device_getDevice_Query = {
  variables: Device_getDevice_Query$variables;
  response: Device_getDevice_Query$data;
};

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
  "name": "__typename",
  "storageKey": null
},
v10 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "rssi",
  "storageKey": null
},
v11 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "slot",
  "storageKey": null
},
v12 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "version",
  "storageKey": null
},
v13 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "timestamp",
  "storageKey": null
},
v14 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "status",
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
            "concreteType": "SystemModel",
            "kind": "LinkedField",
            "name": "systemModel",
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
            "alias": null,
            "args": null,
            "concreteType": "Modem",
            "kind": "LinkedField",
            "name": "cellularConnection",
            "plural": true,
            "selections": [
              (v9/*: any*/)
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
            "name": "Device_baseImage"
          },
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "Device_osInfo"
          },
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "Device_runtimeInfo"
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
          },
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "Device_otaOperations"
          },
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "CellularConnectionTabs_cellularConnection"
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
            "concreteType": "SystemModel",
            "kind": "LinkedField",
            "name": "systemModel",
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
            "concreteType": "Modem",
            "kind": "LinkedField",
            "name": "cellularConnection",
            "plural": true,
            "selections": [
              (v9/*: any*/),
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "apn",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "carrier",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "cellId",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "imei",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "imsi",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "localAreaCode",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "mobileCountryCode",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "mobileNetworkCode",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "registrationStatus",
                "storageKey": null
              },
              (v10/*: any*/),
              (v11/*: any*/),
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "technology",
                "storageKey": null
              }
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
            "concreteType": "BaseImage",
            "kind": "LinkedField",
            "name": "baseImage",
            "plural": false,
            "selections": [
              (v6/*: any*/),
              (v12/*: any*/),
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "buildId",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "fingerprint",
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
              (v12/*: any*/)
            ],
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "concreteType": "RuntimeInfo",
            "kind": "LinkedField",
            "name": "runtimeInfo",
            "plural": false,
            "selections": [
              (v6/*: any*/),
              (v12/*: any*/),
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "environment",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "url",
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
              (v13/*: any*/)
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
              (v13/*: any*/)
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
              (v10/*: any*/),
              (v13/*: any*/)
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
              (v11/*: any*/),
              (v14/*: any*/),
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
          },
          {
            "alias": null,
            "args": null,
            "concreteType": "OtaOperation",
            "kind": "LinkedField",
            "name": "otaOperations",
            "plural": true,
            "selections": [
              (v2/*: any*/),
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "baseImageUrl",
                "storageKey": null
              },
              (v14/*: any*/),
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "createdAt",
                "storageKey": null
              },
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "updatedAt",
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
    "cacheID": "88022510bc0dc22c358aa9b685d38a0e",
    "id": null,
    "metadata": {},
    "name": "Device_getDevice_Query",
    "operationKind": "query",
    "text": "query Device_getDevice_Query(\n  $id: ID!\n) {\n  device(id: $id) {\n    id\n    deviceId\n    lastConnection\n    lastDisconnection\n    name\n    online\n    systemModel {\n      name\n      pictureUrl\n      hardwareType {\n        name\n        id\n      }\n      id\n    }\n    cellularConnection {\n      __typename\n    }\n    ...Device_hardwareInfo\n    ...Device_baseImage\n    ...Device_osInfo\n    ...Device_runtimeInfo\n    ...Device_location\n    ...Device_storageUsage\n    ...Device_systemStatus\n    ...Device_wifiScanResults\n    ...Device_batteryStatus\n    ...Device_otaOperations\n    ...CellularConnectionTabs_cellularConnection\n  }\n}\n\nfragment CellularConnectionTabs_cellularConnection on Device {\n  cellularConnection {\n    apn\n    carrier\n    cellId\n    imei\n    imsi\n    localAreaCode\n    mobileCountryCode\n    mobileNetworkCode\n    registrationStatus\n    rssi\n    slot\n    technology\n  }\n}\n\nfragment Device_baseImage on Device {\n  baseImage {\n    name\n    version\n    buildId\n    fingerprint\n  }\n}\n\nfragment Device_batteryStatus on Device {\n  batteryStatus {\n    slot\n    status\n    levelPercentage\n    levelAbsoluteError\n  }\n}\n\nfragment Device_hardwareInfo on Device {\n  hardwareInfo {\n    cpuArchitecture\n    cpuModel\n    cpuModelName\n    cpuVendor\n    memoryTotalBytes\n  }\n}\n\nfragment Device_location on Device {\n  location {\n    latitude\n    longitude\n    accuracy\n    address\n    timestamp\n  }\n}\n\nfragment Device_osInfo on Device {\n  osInfo {\n    name\n    version\n  }\n}\n\nfragment Device_otaOperations on Device {\n  id\n  otaOperations {\n    id\n    baseImageUrl\n    status\n  }\n  ...OperationTable_otaOperations\n}\n\nfragment Device_runtimeInfo on Device {\n  runtimeInfo {\n    name\n    version\n    environment\n    url\n  }\n}\n\nfragment Device_storageUsage on Device {\n  storageUsage {\n    label\n    totalBytes\n    freeBytes\n  }\n}\n\nfragment Device_systemStatus on Device {\n  systemStatus {\n    memoryFreeBytes\n    taskCount\n    uptimeMilliseconds\n    timestamp\n  }\n}\n\nfragment Device_wifiScanResults on Device {\n  wifiScanResults {\n    channel\n    essid\n    macAddress\n    rssi\n    timestamp\n  }\n}\n\nfragment OperationTable_otaOperations on Device {\n  otaOperations {\n    baseImageUrl\n    createdAt\n    status\n    updatedAt\n    id\n  }\n}\n"
  }
};
})();

(node as any).hash = "90c7adb3db30b183536904549b5c7d04";

export default node;
