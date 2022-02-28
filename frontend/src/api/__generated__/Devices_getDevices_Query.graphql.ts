/**
 * @generated SignedSource<<c8fa7aa7fb09c0b592d0a03aa8c044f6>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Query } from 'relay-runtime';
export type Devices_getDevices_Query$variables = {};
export type Devices_getDevices_Query$data = {
  readonly devices: ReadonlyArray<{
    readonly id: string;
    readonly deviceId: string;
    readonly lastConnection: string | null;
    readonly lastDisconnection: string | null;
    readonly name: string;
    readonly online: boolean;
    readonly systemModel: {
      readonly name: string;
      readonly hardwareType: {
        readonly name: string;
      };
    } | null;
  }>;
};
export type Devices_getDevices_Query = {
  variables: Devices_getDevices_Query$variables;
  response: Devices_getDevices_Query$data;
};

const node: ConcreteRequest = (function(){
var v0 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "id",
  "storageKey": null
},
v1 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "deviceId",
  "storageKey": null
},
v2 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "lastConnection",
  "storageKey": null
},
v3 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "lastDisconnection",
  "storageKey": null
},
v4 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "name",
  "storageKey": null
},
v5 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "online",
  "storageKey": null
};
return {
  "fragment": {
    "argumentDefinitions": [],
    "kind": "Fragment",
    "metadata": null,
    "name": "Devices_getDevices_Query",
    "selections": [
      {
        "alias": null,
        "args": null,
        "concreteType": "Device",
        "kind": "LinkedField",
        "name": "devices",
        "plural": true,
        "selections": [
          (v0/*: any*/),
          (v1/*: any*/),
          (v2/*: any*/),
          (v3/*: any*/),
          (v4/*: any*/),
          (v5/*: any*/),
          {
            "alias": null,
            "args": null,
            "concreteType": "SystemModel",
            "kind": "LinkedField",
            "name": "systemModel",
            "plural": false,
            "selections": [
              (v4/*: any*/),
              {
                "alias": null,
                "args": null,
                "concreteType": "HardwareType",
                "kind": "LinkedField",
                "name": "hardwareType",
                "plural": false,
                "selections": [
                  (v4/*: any*/)
                ],
                "storageKey": null
              }
            ],
            "storageKey": null
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
    "argumentDefinitions": [],
    "kind": "Operation",
    "name": "Devices_getDevices_Query",
    "selections": [
      {
        "alias": null,
        "args": null,
        "concreteType": "Device",
        "kind": "LinkedField",
        "name": "devices",
        "plural": true,
        "selections": [
          (v0/*: any*/),
          (v1/*: any*/),
          (v2/*: any*/),
          (v3/*: any*/),
          (v4/*: any*/),
          (v5/*: any*/),
          {
            "alias": null,
            "args": null,
            "concreteType": "SystemModel",
            "kind": "LinkedField",
            "name": "systemModel",
            "plural": false,
            "selections": [
              (v4/*: any*/),
              {
                "alias": null,
                "args": null,
                "concreteType": "HardwareType",
                "kind": "LinkedField",
                "name": "hardwareType",
                "plural": false,
                "selections": [
                  (v4/*: any*/),
                  (v0/*: any*/)
                ],
                "storageKey": null
              },
              (v0/*: any*/)
            ],
            "storageKey": null
          }
        ],
        "storageKey": null
      }
    ]
  },
  "params": {
    "cacheID": "f2e10f3e1a76a7507fe6c437feb84f5b",
    "id": null,
    "metadata": {},
    "name": "Devices_getDevices_Query",
    "operationKind": "query",
    "text": "query Devices_getDevices_Query {\n  devices {\n    id\n    deviceId\n    lastConnection\n    lastDisconnection\n    name\n    online\n    systemModel {\n      name\n      hardwareType {\n        name\n        id\n      }\n      id\n    }\n  }\n}\n"
  }
};
})();

(node as any).hash = "290893818640c25c5a3299d46589159d";

export default node;
