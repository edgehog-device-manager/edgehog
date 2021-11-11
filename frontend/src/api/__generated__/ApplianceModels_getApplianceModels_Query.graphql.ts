/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type ApplianceModels_getApplianceModels_QueryVariables = {};
export type ApplianceModels_getApplianceModels_QueryResponse = {
    readonly applianceModels: ReadonlyArray<{
        readonly id: string;
        readonly handle: string;
        readonly name: string;
        readonly hardwareType: {
            readonly name: string;
        };
        readonly partNumbers: ReadonlyArray<string>;
    }>;
};
export type ApplianceModels_getApplianceModels_Query = {
    readonly response: ApplianceModels_getApplianceModels_QueryResponse;
    readonly variables: ApplianceModels_getApplianceModels_QueryVariables;
};



/*
query ApplianceModels_getApplianceModels_Query {
  applianceModels {
    id
    handle
    name
    hardwareType {
      name
      id
    }
    partNumbers
  }
}
*/

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
    "name": "ApplianceModels_getApplianceModels_Query",
    "selections": [
      {
        "alias": null,
        "args": null,
        "concreteType": "ApplianceModel",
        "kind": "LinkedField",
        "name": "applianceModels",
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
    "name": "ApplianceModels_getApplianceModels_Query",
    "selections": [
      {
        "alias": null,
        "args": null,
        "concreteType": "ApplianceModel",
        "kind": "LinkedField",
        "name": "applianceModels",
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
    "cacheID": "aaf361608339c841c9f62256f71b0f5b",
    "id": null,
    "metadata": {},
    "name": "ApplianceModels_getApplianceModels_Query",
    "operationKind": "query",
    "text": "query ApplianceModels_getApplianceModels_Query {\n  applianceModels {\n    id\n    handle\n    name\n    hardwareType {\n      name\n      id\n    }\n    partNumbers\n  }\n}\n"
  }
};
})();
(node as any).hash = '801811fbacb566b2bea4ab1814946729';
export default node;
