/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type SystemModel_getSystemModel_QueryVariables = {
    id: string;
};
export type SystemModel_getSystemModel_QueryResponse = {
    readonly systemModel: {
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
export type SystemModel_getSystemModel_Query = {
    readonly response: SystemModel_getSystemModel_QueryResponse;
    readonly variables: SystemModel_getSystemModel_QueryVariables;
};



/*
query SystemModel_getSystemModel_Query(
  $id: ID!
) {
  systemModel(id: $id) {
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
    "concreteType": "SystemModel",
    "kind": "LinkedField",
    "name": "systemModel",
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
    "name": "SystemModel_getSystemModel_Query",
    "selections": (v3/*: any*/),
    "type": "RootQueryType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "SystemModel_getSystemModel_Query",
    "selections": (v3/*: any*/)
  },
  "params": {
    "cacheID": "581675987ad56a64d5ee73e6b099c3a7",
    "id": null,
    "metadata": {},
    "name": "SystemModel_getSystemModel_Query",
    "operationKind": "query",
    "text": "query SystemModel_getSystemModel_Query(\n  $id: ID!\n) {\n  systemModel(id: $id) {\n    id\n    name\n    handle\n    description {\n      locale\n      text\n    }\n    hardwareType {\n      id\n      name\n    }\n    partNumbers\n    pictureUrl\n  }\n}\n"
  }
};
})();
(node as any).hash = '9df2d20636e4b5e30ebab4c70300f4af';
export default node;
