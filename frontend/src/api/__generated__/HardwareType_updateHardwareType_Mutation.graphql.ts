/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type UpdateHardwareTypeInput = {
    handle: string;
    hardwareTypeId: string;
    name: string;
    partNumbers: Array<string>;
};
export type HardwareType_updateHardwareType_MutationVariables = {
    input: UpdateHardwareTypeInput;
};
export type HardwareType_updateHardwareType_MutationResponse = {
    readonly updateHardwareType: {
        readonly hardwareType: {
            readonly id: string;
            readonly name: string;
            readonly handle: string;
            readonly partNumbers: ReadonlyArray<string>;
        };
    } | null;
};
export type HardwareType_updateHardwareType_Mutation = {
    readonly response: HardwareType_updateHardwareType_MutationResponse;
    readonly variables: HardwareType_updateHardwareType_MutationVariables;
};



/*
mutation HardwareType_updateHardwareType_Mutation(
  $input: UpdateHardwareTypeInput!
) {
  updateHardwareType(input: $input) {
    hardwareType {
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
    "concreteType": "UpdateHardwareTypePayload",
    "kind": "LinkedField",
    "name": "updateHardwareType",
    "plural": false,
    "selections": [
      {
        "alias": null,
        "args": null,
        "concreteType": "HardwareType",
        "kind": "LinkedField",
        "name": "hardwareType",
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
    "name": "HardwareType_updateHardwareType_Mutation",
    "selections": (v1/*: any*/),
    "type": "RootMutationType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "HardwareType_updateHardwareType_Mutation",
    "selections": (v1/*: any*/)
  },
  "params": {
    "cacheID": "05a4bfd3f5e046077d32b52cdc846f60",
    "id": null,
    "metadata": {},
    "name": "HardwareType_updateHardwareType_Mutation",
    "operationKind": "mutation",
    "text": "mutation HardwareType_updateHardwareType_Mutation(\n  $input: UpdateHardwareTypeInput!\n) {\n  updateHardwareType(input: $input) {\n    hardwareType {\n      id\n      name\n      handle\n      partNumbers\n    }\n  }\n}\n"
  }
};
})();
(node as any).hash = 'eb28ffad976ac36ef8bb572ba782f70c';
export default node;
