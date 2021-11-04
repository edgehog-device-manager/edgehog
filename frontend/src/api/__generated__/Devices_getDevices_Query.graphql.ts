/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type Devices_getDevices_QueryVariables = {};
export type Devices_getDevices_QueryResponse = {
    readonly devices: ReadonlyArray<{
        readonly id: string;
        readonly deviceId: string;
        readonly name: string;
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
    name
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
        "name": "name",
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
    "cacheID": "177a433a3dad04bb67c1650985a8eeb9",
    "id": null,
    "metadata": {},
    "name": "Devices_getDevices_Query",
    "operationKind": "query",
    "text": "query Devices_getDevices_Query {\n  devices {\n    id\n    deviceId\n    name\n  }\n}\n"
  }
};
})();
(node as any).hash = '57e2bf5ffc288d9b21f85a5e0128146c';
export default node;
