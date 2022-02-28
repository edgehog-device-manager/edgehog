/**
 * @generated SignedSource<<eca8d17af21cc9607d103c89286c58a8>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Query } from 'relay-runtime';
export type HardwareType_getHardwareType_Query$variables = {
  id: string;
};
export type HardwareType_getHardwareType_Query$data = {
  readonly hardwareType: {
    readonly id: string;
    readonly name: string;
    readonly handle: string;
    readonly partNumbers: ReadonlyArray<string>;
  } | null;
};
export type HardwareType_getHardwareType_Query = {
  variables: HardwareType_getHardwareType_Query$variables;
  response: HardwareType_getHardwareType_Query$data;
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
    "alias": null,
    "args": [
      {
        "kind": "Variable",
        "name": "id",
        "variableName": "id"
      }
    ],
    "concreteType": "HardwareType",
    "kind": "LinkedField",
    "name": "hardwareType",
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
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "handle",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "partNumbers",
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
    "name": "HardwareType_getHardwareType_Query",
    "selections": (v1/*: any*/),
    "type": "RootQueryType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "HardwareType_getHardwareType_Query",
    "selections": (v1/*: any*/)
  },
  "params": {
    "cacheID": "5054f0dae08cbd8999bf807cc6041428",
    "id": null,
    "metadata": {},
    "name": "HardwareType_getHardwareType_Query",
    "operationKind": "query",
    "text": "query HardwareType_getHardwareType_Query(\n  $id: ID!\n) {\n  hardwareType(id: $id) {\n    id\n    name\n    handle\n    partNumbers\n  }\n}\n"
  }
};
})();

(node as any).hash = "0c819c24c6c6095f8bbafbcfec7f0920";

export default node;
