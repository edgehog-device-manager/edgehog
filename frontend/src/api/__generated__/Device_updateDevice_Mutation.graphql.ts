/**
 * @generated SignedSource<<512afcc50b3c9fa98667fd1d97452637>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Mutation } from 'relay-runtime';
export type UpdateDeviceInput = {
  deviceId: string;
  name?: string | null;
};
export type Device_updateDevice_Mutation$variables = {
  input: UpdateDeviceInput;
};
export type Device_updateDevice_Mutation$data = {
  readonly updateDevice: {
    readonly device: {
      readonly id: string;
      readonly name: string;
    };
  } | null;
};
export type Device_updateDevice_Mutation = {
  variables: Device_updateDevice_Mutation$variables;
  response: Device_updateDevice_Mutation$data;
};

const node: ConcreteRequest = (function(){
var v0 = [
  {
    "defaultValue": null,
    "kind": "LocalArgument",
    "name": "input"
  }
],
v1 = [
  {
    "alias": null,
    "args": [
      {
        "kind": "Variable",
        "name": "input",
        "variableName": "input"
      }
    ],
    "concreteType": "UpdateDevicePayload",
    "kind": "LinkedField",
    "name": "updateDevice",
    "plural": false,
    "selections": [
      {
        "alias": null,
        "args": null,
        "concreteType": "Device",
        "kind": "LinkedField",
        "name": "device",
        "plural": false,
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
            "name": "name",
            "storageKey": null
          }
        ],
        "storageKey": null
      }
    ],
    "storageKey": null
  }
];
return {
  "fragment": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Fragment",
    "metadata": null,
    "name": "Device_updateDevice_Mutation",
    "selections": (v1/*: any*/),
    "type": "RootMutationType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "Device_updateDevice_Mutation",
    "selections": (v1/*: any*/)
  },
  "params": {
    "cacheID": "a56251ab3c26122bd4baed740e271b58",
    "id": null,
    "metadata": {},
    "name": "Device_updateDevice_Mutation",
    "operationKind": "mutation",
    "text": "mutation Device_updateDevice_Mutation(\n  $input: UpdateDeviceInput!\n) {\n  updateDevice(input: $input) {\n    device {\n      id\n      name\n    }\n  }\n}\n"
  }
};
})();

(node as any).hash = "2ea79c86352e1abc0cccd50440cc67ea";

export default node;
