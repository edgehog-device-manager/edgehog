/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type UpdateApplianceModelInput = {
    applianceModelId: string;
    description?: LocalizedTextInput | null | undefined;
    handle?: string | null | undefined;
    name?: string | null | undefined;
    partNumbers?: Array<string> | null | undefined;
    pictureFile?: File | null | undefined;
    pictureUrl?: string | null | undefined;
};
export type LocalizedTextInput = {
    locale: string;
    text: string;
};
export type ApplianceModel_updateApplianceModel_MutationVariables = {
    input: UpdateApplianceModelInput;
};
export type ApplianceModel_updateApplianceModel_MutationResponse = {
    readonly updateApplianceModel: {
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
export type ApplianceModel_updateApplianceModel_Mutation = {
    readonly response: ApplianceModel_updateApplianceModel_MutationResponse;
    readonly variables: ApplianceModel_updateApplianceModel_MutationVariables;
};



/*
mutation ApplianceModel_updateApplianceModel_Mutation(
  $input: UpdateApplianceModelInput!
) {
  updateApplianceModel(input: $input) {
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
    "concreteType": "UpdateApplianceModelPayload",
    "kind": "LinkedField",
    "name": "updateApplianceModel",
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
    "name": "ApplianceModel_updateApplianceModel_Mutation",
    "selections": (v3/*: any*/),
    "type": "RootMutationType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "ApplianceModel_updateApplianceModel_Mutation",
    "selections": (v3/*: any*/)
  },
  "params": {
    "cacheID": "920a4668ae9356be0a72ec1b275b70b3",
    "id": null,
    "metadata": {},
    "name": "ApplianceModel_updateApplianceModel_Mutation",
    "operationKind": "mutation",
    "text": "mutation ApplianceModel_updateApplianceModel_Mutation(\n  $input: UpdateApplianceModelInput!\n) {\n  updateApplianceModel(input: $input) {\n    applianceModel {\n      id\n      name\n      handle\n      description {\n        locale\n        text\n      }\n      hardwareType {\n        id\n        name\n      }\n      partNumbers\n      pictureUrl\n    }\n  }\n}\n"
  }
};
})();
(node as any).hash = '74ed7e134a496195539fe5183d49a5ff';
export default node;
