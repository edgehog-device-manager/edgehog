/**
 * @generated SignedSource<<8eb8a88c8baf1db69dca63d191404d93>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Mutation } from 'relay-runtime';
export type LedBehavior = "BLINK" | "DOUBLE_BLINK" | "SLOW_BLINK" | "%future added value";
export type SetLedBehaviorInput = {
  deviceId: string;
  behavior: LedBehavior;
};
export type LedBehaviorDropdown_setLedBehavior_Mutation$variables = {
  input: SetLedBehaviorInput;
};
export type LedBehaviorDropdown_setLedBehavior_Mutation$data = {
  readonly setLedBehavior: {
    readonly behavior: LedBehavior;
  } | null;
};
export type LedBehaviorDropdown_setLedBehavior_Mutation = {
  variables: LedBehaviorDropdown_setLedBehavior_Mutation$variables;
  response: LedBehaviorDropdown_setLedBehavior_Mutation$data;
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
    "concreteType": "SetLedBehaviorPayload",
    "kind": "LinkedField",
    "name": "setLedBehavior",
    "plural": false,
    "selections": [
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "behavior",
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
    "name": "LedBehaviorDropdown_setLedBehavior_Mutation",
    "selections": (v1/*: any*/),
    "type": "RootMutationType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "LedBehaviorDropdown_setLedBehavior_Mutation",
    "selections": (v1/*: any*/)
  },
  "params": {
    "cacheID": "45e4760b91f125e9438362654d06ec0c",
    "id": null,
    "metadata": {},
    "name": "LedBehaviorDropdown_setLedBehavior_Mutation",
    "operationKind": "mutation",
    "text": "mutation LedBehaviorDropdown_setLedBehavior_Mutation(\n  $input: SetLedBehaviorInput!\n) {\n  setLedBehavior(input: $input) {\n    behavior\n  }\n}\n"
  }
};
})();

(node as any).hash = "20fbb73638f1245c58fb2800a2547a6f";

export default node;
