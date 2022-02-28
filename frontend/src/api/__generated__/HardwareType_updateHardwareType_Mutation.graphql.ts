/**
 * @generated SignedSource<<e6350e81e18cdec83d50f28615e759f0>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Mutation } from 'relay-runtime';
export type UpdateHardwareTypeInput = {
  hardwareTypeId: string;
  name?: string | null;
  handle?: string | null;
  partNumbers?: ReadonlyArray<string> | null;
};
export type HardwareType_updateHardwareType_Mutation$variables = {
  input: UpdateHardwareTypeInput;
};
export type HardwareType_updateHardwareType_Mutation$data = {
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
  variables: HardwareType_updateHardwareType_Mutation$variables;
  response: HardwareType_updateHardwareType_Mutation$data;
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

(node as any).hash = "eb28ffad976ac36ef8bb572ba782f70c";

export default node;
