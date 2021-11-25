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
            readonly hardwareType: {
                readonly name: string;
            };
            readonly partNumbers: ReadonlyArray<string>;
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
      hardwareType {
        name
        id
      }
      partNumbers
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
v1 = [
  {
    "kind": "Variable",
    "name": "input",
    "variableName": "input"
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
    "name": "ApplianceModelCreate_createApplianceModel_Mutation",
    "selections": [
      {
        "alias": null,
        "args": (v1/*: any*/),
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
        "storageKey": null
      }
    ],
    "type": "RootMutationType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "ApplianceModelCreate_createApplianceModel_Mutation",
    "selections": [
      {
        "alias": null,
        "args": (v1/*: any*/),
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
        ],
        "storageKey": null
      }
    ]
  },
  "params": {
    "cacheID": "cbdbb635cfcec74bf4b17482554977ca",
    "id": null,
    "metadata": {},
    "name": "ApplianceModelCreate_createApplianceModel_Mutation",
    "operationKind": "mutation",
    "text": "mutation ApplianceModelCreate_createApplianceModel_Mutation(\n  $input: CreateApplianceModelInput!\n) {\n  createApplianceModel(input: $input) {\n    applianceModel {\n      id\n      name\n      handle\n      hardwareType {\n        name\n        id\n      }\n      partNumbers\n    }\n  }\n}\n"
  }
};
})();
(node as any).hash = 'a62677a22f410b5881f3584a9bbbd80a';
export default node;
