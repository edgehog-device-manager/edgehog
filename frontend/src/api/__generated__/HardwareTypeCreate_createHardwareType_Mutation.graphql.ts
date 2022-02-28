/**
 * @generated SignedSource<<c6df4056bdf1ed994b4ffa245f325294>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Mutation } from 'relay-runtime';
export type CreateHardwareTypeInput = {
  name: string;
  handle: string;
  partNumbers: ReadonlyArray<string>;
};
export type HardwareTypeCreate_createHardwareType_Mutation$variables = {
  input: CreateHardwareTypeInput;
};
export type HardwareTypeCreate_createHardwareType_Mutation$data = {
  readonly createHardwareType: {
    readonly hardwareType: {
      readonly id: string;
      readonly name: string;
      readonly handle: string;
      readonly partNumbers: ReadonlyArray<string>;
    };
  } | null;
};
export type HardwareTypeCreate_createHardwareType_Mutation = {
  variables: HardwareTypeCreate_createHardwareType_Mutation$variables;
  response: HardwareTypeCreate_createHardwareType_Mutation$data;
};

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
    "concreteType": "CreateHardwareTypePayload",
    "kind": "LinkedField",
    "name": "createHardwareType",
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
    "name": "HardwareTypeCreate_createHardwareType_Mutation",
    "selections": (v1/*: any*/),
    "type": "RootMutationType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "HardwareTypeCreate_createHardwareType_Mutation",
    "selections": (v1/*: any*/)
  },
  "params": {
    "cacheID": "a21a082a93604598f2f3ad26158955fd",
    "id": null,
    "metadata": {},
    "name": "HardwareTypeCreate_createHardwareType_Mutation",
    "operationKind": "mutation",
    "text": "mutation HardwareTypeCreate_createHardwareType_Mutation(\n  $input: CreateHardwareTypeInput!\n) {\n  createHardwareType(input: $input) {\n    hardwareType {\n      id\n      name\n      handle\n      partNumbers\n    }\n  }\n}\n"
  }
};
})();

(node as any).hash = "4414cd1057105410443d05c2b7084936";

export default node;
