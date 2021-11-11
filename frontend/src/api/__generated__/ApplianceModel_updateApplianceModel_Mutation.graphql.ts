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
          },
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
            "kind": "ScalarField",
            "name": "partNumbers",
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
    "selections": (v1/*: any*/),
    "type": "RootMutationType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "ApplianceModel_updateApplianceModel_Mutation",
    "selections": (v1/*: any*/)
  },
  "params": {
    "cacheID": "6f48ebdf8a405d98e4066f31e1e89f2b",
    "id": null,
    "metadata": {},
    "name": "ApplianceModel_updateApplianceModel_Mutation",
    "operationKind": "mutation",
    "text": "mutation ApplianceModel_updateApplianceModel_Mutation(\n  $input: UpdateApplianceModelInput!\n) {\n  updateApplianceModel(input: $input) {\n    applianceModel {\n      id\n      name\n      handle\n      partNumbers\n    }\n  }\n}\n"
  }
};
})();
(node as any).hash = '267d734e3942e1153b75b3644ba9921d';
export default node;
