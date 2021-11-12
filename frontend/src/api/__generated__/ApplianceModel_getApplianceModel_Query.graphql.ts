/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type ApplianceModel_getApplianceModel_QueryVariables = {
    id: string;
};
export type ApplianceModel_getApplianceModel_QueryResponse = {
    readonly applianceModel: {
        readonly id: string;
        readonly name: string;
        readonly handle: string;
        readonly hardwareType: {
            readonly name: string;
        };
        readonly partNumbers: ReadonlyArray<string>;
    } | null;
};
export type ApplianceModel_getApplianceModel_Query = {
    readonly response: ApplianceModel_getApplianceModel_QueryResponse;
    readonly variables: ApplianceModel_getApplianceModel_QueryVariables;
};



/*
query ApplianceModel_getApplianceModel_Query(
  $id: ID!
) {
  applianceModel(id: $id) {
    id
    name
    handle
    hardwareType {
      name
      id
    }
    partNumbers
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
  "name": "name",
  "storageKey": null
},
v4 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "handle",
  "storageKey": null
},
v5 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "partNumbers",
  "storageKey": null
};
return {
  "fragment": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Fragment",
    "metadata": null,
    "name": "ApplianceModel_getApplianceModel_Query",
    "selections": [
      {
        "alias": null,
        "args": (v1/*: any*/),
        "concreteType": "ApplianceModel",
        "kind": "LinkedField",
        "name": "applianceModel",
        "plural": false,
        "selections": [
          (v2/*: any*/),
          (v3/*: any*/),
          (v4/*: any*/),
          {
            "alias": null,
            "args": null,
            "concreteType": "HardwareType",
            "kind": "LinkedField",
            "name": "hardwareType",
            "plural": false,
            "selections": [
              (v3/*: any*/)
            ],
            "storageKey": null
          },
          (v5/*: any*/)
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
    "name": "ApplianceModel_getApplianceModel_Query",
    "selections": [
      {
        "alias": null,
        "args": (v1/*: any*/),
        "concreteType": "ApplianceModel",
        "kind": "LinkedField",
        "name": "applianceModel",
        "plural": false,
        "selections": [
          (v2/*: any*/),
          (v3/*: any*/),
          (v4/*: any*/),
          {
            "alias": null,
            "args": null,
            "concreteType": "HardwareType",
            "kind": "LinkedField",
            "name": "hardwareType",
            "plural": false,
            "selections": [
              (v3/*: any*/),
              (v2/*: any*/)
            ],
            "storageKey": null
          },
          (v5/*: any*/)
        ],
        "storageKey": null
      }
    ]
  },
  "params": {
    "cacheID": "3b28e91c81fab0d2f5323022a662027d",
    "id": null,
    "metadata": {},
    "name": "ApplianceModel_getApplianceModel_Query",
    "operationKind": "query",
    "text": "query ApplianceModel_getApplianceModel_Query(\n  $id: ID!\n) {\n  applianceModel(id: $id) {\n    id\n    name\n    handle\n    hardwareType {\n      name\n      id\n    }\n    partNumbers\n  }\n}\n"
  }
};
})();
(node as any).hash = '7c7bfe8025d1c2e268311a1c6dcf618f';
export default node;
