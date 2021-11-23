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
            readonly hardwareType: {
                readonly name: string;
            };
        } | null;
        readonly " $fragmentRefs": FragmentRefs<"Device_hardwareInfo" | "Device_location">;
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
      hardwareType {
        name
        id
      }
      id
    }
    ...Device_hardwareInfo
    ...Device_location
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
            "name": "Device_location"
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
              {
                "alias": null,
                "args": null,
                "kind": "ScalarField",
                "name": "timestamp",
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
    "cacheID": "89831941bd6285468fe43264c791bd17",
    "id": null,
    "metadata": {},
    "name": "Device_getDevice_Query",
    "operationKind": "query",
    "text": "query Device_getDevice_Query(\n  $id: ID!\n) {\n  device(id: $id) {\n    id\n    deviceId\n    lastConnection\n    lastDisconnection\n    name\n    online\n    applianceModel {\n      name\n      hardwareType {\n        name\n        id\n      }\n      id\n    }\n    ...Device_hardwareInfo\n    ...Device_location\n  }\n}\n\nfragment Device_hardwareInfo on Device {\n  hardwareInfo {\n    cpuArchitecture\n    cpuModel\n    cpuModelName\n    cpuVendor\n    memoryTotalBytes\n  }\n}\n\nfragment Device_location on Device {\n  location {\n    latitude\n    longitude\n    accuracy\n    address\n    timestamp\n  }\n}\n"
  }
};
})();
(node as any).hash = '459ff9d7db3b20242da30cf4088cff44';
export default node;
