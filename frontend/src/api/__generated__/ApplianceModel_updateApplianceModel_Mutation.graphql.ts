/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type UpdateApplianceModelInput = {
    applianceModelId: string;
    handle?: string | null | undefined;
    name?: string | null | undefined;
    partNumbers?: Array<string> | null | undefined;
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
            readonly hardwareType: {
                readonly name: string;
            };
            readonly partNumbers: ReadonlyArray<string>;
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
    "name": "ApplianceModel_updateApplianceModel_Mutation",
    "selections": [
      {
        "alias": null,
        "args": (v1/*: any*/),
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
    "name": "ApplianceModel_updateApplianceModel_Mutation",
    "selections": [
      {
        "alias": null,
        "args": (v1/*: any*/),
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
    "cacheID": "5a0bac3786d3f4923be151a021a6fd31",
    "id": null,
    "metadata": {},
    "name": "ApplianceModel_updateApplianceModel_Mutation",
    "operationKind": "mutation",
    "text": "mutation ApplianceModel_updateApplianceModel_Mutation(\n  $input: UpdateApplianceModelInput!\n) {\n  updateApplianceModel(input: $input) {\n    applianceModel {\n      id\n      name\n      handle\n      hardwareType {\n        name\n        id\n      }\n      partNumbers\n    }\n  }\n}\n"
  }
};
})();
(node as any).hash = 'a141651959d1f19e0258091ebe404ad1';
export default node;
