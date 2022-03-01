/**
 * @generated SignedSource<<49e0d072d4226bcecf0eadb451c512c5>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Query } from 'relay-runtime';
export type SystemModels_getSystemModels_Query$variables = {};
export type SystemModels_getSystemModels_Query$data = {
  readonly systemModels: ReadonlyArray<{
    readonly id: string;
    readonly handle: string;
    readonly name: string;
    readonly hardwareType: {
      readonly name: string;
    };
    readonly partNumbers: ReadonlyArray<string>;
  }>;
};
export type SystemModels_getSystemModels_Query = {
  variables: SystemModels_getSystemModels_Query$variables;
  response: SystemModels_getSystemModels_Query$data;
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
  "name": "handle",
  "storageKey": null
},
v2 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "name",
  "storageKey": null
},
v3 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "partNumbers",
  "storageKey": null
};
return {
  "fragment": {
    "argumentDefinitions": [],
    "kind": "Fragment",
    "metadata": null,
    "name": "SystemModels_getSystemModels_Query",
    "selections": [
      {
        "alias": null,
        "args": null,
        "concreteType": "SystemModel",
        "kind": "LinkedField",
        "name": "systemModels",
        "plural": true,
        "selections": [
          (v0/*: any*/),
          (v1/*: any*/),
          (v2/*: any*/),
          {
            "alias": null,
            "args": null,
            "concreteType": "HardwareType",
            "kind": "LinkedField",
            "name": "hardwareType",
            "plural": false,
            "selections": [
              (v2/*: any*/)
            ],
            "storageKey": null
          },
          (v3/*: any*/)
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
    "name": "SystemModels_getSystemModels_Query",
    "selections": [
      {
        "alias": null,
        "args": null,
        "concreteType": "SystemModel",
        "kind": "LinkedField",
        "name": "systemModels",
        "plural": true,
        "selections": [
          (v0/*: any*/),
          (v1/*: any*/),
          (v2/*: any*/),
          {
            "alias": null,
            "args": null,
            "concreteType": "HardwareType",
            "kind": "LinkedField",
            "name": "hardwareType",
            "plural": false,
            "selections": [
              (v2/*: any*/),
              (v0/*: any*/)
            ],
            "storageKey": null
          },
          (v3/*: any*/)
        ],
        "storageKey": null
      }
    ]
  },
  "params": {
    "cacheID": "7a39aa36dfc3d3f67c9525ddeffc6dd7",
    "id": null,
    "metadata": {},
    "name": "SystemModels_getSystemModels_Query",
    "operationKind": "query",
    "text": "query SystemModels_getSystemModels_Query {\n  systemModels {\n    id\n    handle\n    name\n    hardwareType {\n      name\n      id\n    }\n    partNumbers\n  }\n}\n"
  }
};
})();

(node as any).hash = "88c1d0553cfbbfcf7c4fa349dd408ebb";

export default node;
