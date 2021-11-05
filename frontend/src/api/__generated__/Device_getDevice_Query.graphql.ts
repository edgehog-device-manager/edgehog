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
        readonly name: string;
        readonly " $fragmentRefs": FragmentRefs<"Device_hardwareInfo">;
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
    name
    ...Device_hardwareInfo
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
  "name": "name",
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
          {
            "args": null,
            "kind": "FragmentSpread",
            "name": "Device_hardwareInfo"
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
          }
        ],
        "storageKey": null
      }
    ]
  },
  "params": {
    "cacheID": "ecf8295df3b12b8033644834f38a6de8",
    "id": null,
    "metadata": {},
    "name": "Device_getDevice_Query",
    "operationKind": "query",
    "text": "query Device_getDevice_Query(\n  $id: ID!\n) {\n  device(id: $id) {\n    id\n    deviceId\n    name\n    ...Device_hardwareInfo\n  }\n}\n\nfragment Device_hardwareInfo on Device {\n  hardwareInfo {\n    cpuArchitecture\n    cpuModel\n    cpuModelName\n    cpuVendor\n    memoryTotalBytes\n  }\n}\n"
  }
};
})();
(node as any).hash = '23b7ea334e427de2fff737225e182246';
export default node;
