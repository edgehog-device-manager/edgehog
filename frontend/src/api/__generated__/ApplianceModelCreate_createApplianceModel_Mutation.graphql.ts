/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type CreateApplianceModelInput = {
    description?: LocalizedTextInput | null | undefined;
    handle: string;
    hardwareTypeId: string;
    name: string;
    partNumbers: Array<string>;
    pictureFile?: File | null | undefined;
    pictureUrl?: string | null | undefined;
};
export type LocalizedTextInput = {
    locale: string;
    text: string;
};
export type ApplianceModelCreate_createApplianceModel_MutationVariables = {
    input: CreateApplianceModelInput;
};
export type ApplianceModelCreate_createApplianceModel_MutationResponse = {
    readonly createApplianceModel: {
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
        };
    } | null;
};
export type ApplianceModelCreate_createApplianceModel_Mutation = {
    readonly response: ApplianceModelCreate_createApplianceModel_MutationResponse;
    readonly variables: ApplianceModelCreate_createApplianceModel_MutationVariables;
};



/*
mutation ApplianceModelCreate_createApplianceModel_Mutation(
  $input: CreateApplianceModelInput!
) {
  createApplianceModel(input: $input) {
    applianceModel {
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
}
*/

const node: ConcreteRequest = (function(){
var v0 = [
  {
    "defaultValue": null,
    "kind": "LocalArgument",
    "name": "input"
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
        "name": "input",
        "variableName": "input"
      }
    ],
    "concreteType": "CreateApplianceModelPayload",
    "kind": "LinkedField",
    "name": "createApplianceModel",
    "plural": false,
    "selections": [
      {
        "alias": null,
        "args": null,
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
    ],
    "storageKey": null
  }
];
return {
  "fragment": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Fragment",
    "metadata": null,
    "name": "ApplianceModelCreate_createApplianceModel_Mutation",
    "selections": (v3/*: any*/),
    "type": "RootMutationType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "ApplianceModelCreate_createApplianceModel_Mutation",
    "selections": (v3/*: any*/)
  },
  "params": {
    "cacheID": "834882e6924982c9ec6abe63b39d65f8",
    "id": null,
    "metadata": {},
    "name": "ApplianceModelCreate_createApplianceModel_Mutation",
    "operationKind": "mutation",
    "text": "mutation ApplianceModelCreate_createApplianceModel_Mutation(\n  $input: CreateApplianceModelInput!\n) {\n  createApplianceModel(input: $input) {\n    applianceModel {\n      id\n      name\n      handle\n      description {\n        locale\n        text\n      }\n      hardwareType {\n        id\n        name\n      }\n      partNumbers\n      pictureUrl\n    }\n  }\n}\n"
  }
};
})();
(node as any).hash = '48da81ed51d2f22a8c6525eb30bfe5a8';
export default node;
