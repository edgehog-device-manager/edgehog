/**
 * @generated SignedSource<<86c314b54b8f79b5daa8da380810d047>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Mutation } from 'relay-runtime';
export type CreateSystemModelInput = {
  name: string;
  handle: string;
  pictureFile?: File | null;
  pictureUrl?: string | null;
  partNumbers: ReadonlyArray<string>;
  hardwareTypeId: string;
  description?: LocalizedTextInput | null;
};
export type LocalizedTextInput = {
  locale: string;
  text: string;
};
export type SystemModelCreate_createSystemModel_Mutation$variables = {
  input: CreateSystemModelInput;
};
export type SystemModelCreate_createSystemModel_Mutation$data = {
  readonly createSystemModel: {
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
export type SystemModelCreate_createSystemModel_Mutation = {
  variables: SystemModelCreate_createSystemModel_Mutation$variables;
  response: SystemModelCreate_createSystemModel_Mutation$data;
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
    "concreteType": "CreateSystemModelPayload",
    "kind": "LinkedField",
    "name": "createSystemModel",
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
    "name": "SystemModelCreate_createSystemModel_Mutation",
    "selections": (v3/*: any*/),
    "type": "RootMutationType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "SystemModelCreate_createSystemModel_Mutation",
    "selections": (v3/*: any*/)
  },
  "params": {
    "cacheID": "99ca278b5be113b57ef16aefdf6335a6",
    "id": null,
    "metadata": {},
    "name": "SystemModelCreate_createSystemModel_Mutation",
    "operationKind": "mutation",
    "text": "mutation SystemModelCreate_createSystemModel_Mutation(\n  $input: CreateSystemModelInput!\n) {\n  createSystemModel(input: $input) {\n    systemModel {\n      id\n      name\n      handle\n      description {\n        locale\n        text\n      }\n      hardwareType {\n        id\n        name\n      }\n      partNumbers\n      pictureUrl\n    }\n  }\n}\n"
  }
};
})();

(node as any).hash = "974bd67d4943c8842d7db0ef2c529ae9";

export default node;
