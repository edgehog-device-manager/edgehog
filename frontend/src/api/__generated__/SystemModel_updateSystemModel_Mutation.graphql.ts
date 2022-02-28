/**
 * @generated SignedSource<<0ed8189605940dd9d80f6f5a93103680>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Mutation } from 'relay-runtime';
export type UpdateSystemModelInput = {
  systemModelId: string;
  name?: string | null;
  handle?: string | null;
  pictureFile?: File | null;
  pictureUrl?: string | null;
  partNumbers?: ReadonlyArray<string> | null;
  description?: LocalizedTextInput | null;
};
export type LocalizedTextInput = {
  locale: string;
  text: string;
};
export type SystemModel_updateSystemModel_Mutation$variables = {
  input: UpdateSystemModelInput;
};
export type SystemModel_updateSystemModel_Mutation$data = {
  readonly updateSystemModel: {
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
    };
  } | null;
};
export type SystemModel_updateSystemModel_Mutation = {
  variables: SystemModel_updateSystemModel_Mutation$variables;
  response: SystemModel_updateSystemModel_Mutation$data;
};

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
    "concreteType": "UpdateSystemModelPayload",
    "kind": "LinkedField",
    "name": "updateSystemModel",
    "plural": false,
    "selections": [
      {
        "alias": null,
        "args": null,
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
    ],
    "storageKey": null
  }
];
return {
  "fragment": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Fragment",
    "metadata": null,
    "name": "SystemModel_updateSystemModel_Mutation",
    "selections": (v3/*: any*/),
    "type": "RootMutationType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "SystemModel_updateSystemModel_Mutation",
    "selections": (v3/*: any*/)
  },
  "params": {
    "cacheID": "dec24da9f9d4c93090499bf7b7dc665d",
    "id": null,
    "metadata": {},
    "name": "SystemModel_updateSystemModel_Mutation",
    "operationKind": "mutation",
    "text": "mutation SystemModel_updateSystemModel_Mutation(\n  $input: UpdateSystemModelInput!\n) {\n  updateSystemModel(input: $input) {\n    systemModel {\n      id\n      name\n      handle\n      description {\n        locale\n        text\n      }\n      hardwareType {\n        id\n        name\n      }\n      partNumbers\n      pictureUrl\n    }\n  }\n}\n"
  }
};
})();

(node as any).hash = "137b5cd9bc35b763b5de5338e64b8e96";

export default node;
