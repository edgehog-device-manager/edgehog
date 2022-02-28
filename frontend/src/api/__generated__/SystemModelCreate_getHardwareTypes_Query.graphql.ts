/**
 * @generated SignedSource<<695f2c7b071343922bf0757cc243192f>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Query } from 'relay-runtime';
export type SystemModelCreate_getHardwareTypes_Query$variables = {};
export type SystemModelCreate_getHardwareTypes_Query$data = {
  readonly hardwareTypes: ReadonlyArray<{
    readonly id: string;
    readonly name: string;
  }>;
};
export type SystemModelCreate_getHardwareTypes_Query = {
  variables: SystemModelCreate_getHardwareTypes_Query$variables;
  response: SystemModelCreate_getHardwareTypes_Query$data;
};

const node: ConcreteRequest = (function(){
var v0 = [
  {
    "alias": null,
    "args": null,
    "concreteType": "HardwareType",
    "kind": "LinkedField",
    "name": "hardwareTypes",
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
    "name": "SystemModelCreate_getHardwareTypes_Query",
    "selections": (v0/*: any*/),
    "type": "RootQueryType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": [],
    "kind": "Operation",
    "name": "SystemModelCreate_getHardwareTypes_Query",
    "selections": (v0/*: any*/)
  },
  "params": {
    "cacheID": "76e3daaae73ddb9bc24547c388760ec4",
    "id": null,
    "metadata": {},
    "name": "SystemModelCreate_getHardwareTypes_Query",
    "operationKind": "query",
    "text": "query SystemModelCreate_getHardwareTypes_Query {\n  hardwareTypes {\n    id\n    name\n  }\n}\n"
  }
};
})();

(node as any).hash = "4774a09b2bd80451f008336047267152";

export default node;
