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
        readonly description: {
            readonly locale: string;
            readonly text: string;
        } | null;
        readonly hardwareType: {
            readonly id: string;
            readonly name: string;
        };
        readonly partNumbers: ReadonlyArray<string>;
        readonly pictureUrl: string | null;
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
    description {
      locale
      text
    }
    hardwareType {
      id
      name
    }
    partNumbers
    pictureUrl
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
v1 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "id",
  "storageKey": null
},
v2 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "name",
  "storageKey": null
},
v3 = [
  {
    "alias": null,
    "args": [
      {
        "kind": "Variable",
        "name": "id",
        "variableName": "id"
      }
    ],
    "concreteType": "ApplianceModel",
    "kind": "LinkedField",
    "name": "applianceModel",
    "plural": false,
    "selections": [
      (v1/*: any*/),
      (v2/*: any*/),
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
        "concreteType": "LocalizedText",
        "kind": "LinkedField",
        "name": "description",
        "plural": false,
        "selections": [
          {
            "alias": null,
            "args": null,
            "kind": "ScalarField",
            "name": "locale",
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "kind": "ScalarField",
            "name": "text",
            "storageKey": null
          }
        ],
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "concreteType": "HardwareType",
        "kind": "LinkedField",
        "name": "hardwareType",
        "plural": false,
        "selections": [
          (v1/*: any*/),
          (v2/*: any*/)
        ],
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "partNumbers",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "pictureUrl",
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
    "name": "ApplianceModel_getApplianceModel_Query",
    "selections": (v3/*: any*/),
    "type": "RootQueryType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "ApplianceModel_getApplianceModel_Query",
    "selections": (v3/*: any*/)
  },
  "params": {
    "cacheID": "4c60baf2218fff9a867a3bec1cf50c97",
    "id": null,
    "metadata": {},
    "name": "ApplianceModel_getApplianceModel_Query",
    "operationKind": "query",
    "text": "query ApplianceModel_getApplianceModel_Query(\n  $id: ID!\n) {\n  applianceModel(id: $id) {\n    id\n    name\n    handle\n    description {\n      locale\n      text\n    }\n    hardwareType {\n      id\n      name\n    }\n    partNumbers\n    pictureUrl\n  }\n}\n"
  }
};
})();
(node as any).hash = '7f1de306fc4a2d232e7d9525087a5542';
export default node;
