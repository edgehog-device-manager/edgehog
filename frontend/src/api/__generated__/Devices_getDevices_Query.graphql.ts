/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type Devices_getDevices_QueryVariables = {};
export type Devices_getDevices_QueryResponse = {
    readonly devices: ReadonlyArray<{
        readonly id: string;
        readonly deviceId: string;
        readonly lastConnection: string | null;
        readonly lastDisconnection: string | null;
        readonly name: string;
        readonly online: boolean;
    }>;
};
export type Devices_getDevices_Query = {
    readonly response: Devices_getDevices_QueryResponse;
    readonly variables: Devices_getDevices_QueryVariables;
};



/*
query Devices_getDevices_Query {
  devices {
    id
    deviceId
    lastConnection
    lastDisconnection
    name
    online
  }
}
*/

const node: ConcreteRequest = (function(){
var v0 = [
  {
    "alias": null,
    "args": null,
    "concreteType": "Device",
    "kind": "LinkedField",
    "name": "devices",
    "plural": true,
    "selections": [
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "id",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "deviceId",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "lastConnection",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "lastDisconnection",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "name",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "online",
        "storageKey": null
      }
    ],
    "storageKey": null
  }
];
return {
  "fragment": {
    "argumentDefinitions": [],
    "kind": "Fragment",
    "metadata": null,
    "name": "Devices_getDevices_Query",
    "selections": (v0/*: any*/),
    "type": "RootQueryType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": [],
    "kind": "Operation",
    "name": "Devices_getDevices_Query",
    "selections": (v0/*: any*/)
  },
  "params": {
    "cacheID": "4af51fd4b7571ef99553422e4a8555f2",
    "id": null,
    "metadata": {},
    "name": "Devices_getDevices_Query",
    "operationKind": "query",
    "text": "query Devices_getDevices_Query {\n  devices {\n    id\n    deviceId\n    lastConnection\n    lastDisconnection\n    name\n    online\n  }\n}\n"
  }
};
})();
(node as any).hash = '390c4a179e214f3640d4f3285db26746';
export default node;
