/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type OtaOperationStatus = "DONE" | "ERROR" | "IN_PROGRESS" | "PENDING" | "%future added value";
export type OtaOperationStatusCode = "ALREADY_IN_PROGRESS" | "DEPLOY_ERROR" | "FAILED" | "NETWORK_ERROR" | "NVS_ERROR" | "WRONG_PARTITION" | "%future added value";
export type CreateManualOtaOperationInput = {
    baseImageFile?: File | null | undefined;
    deviceId: string;
};
export type Device_createManualOtaOperation_MutationVariables = {
    input: CreateManualOtaOperationInput;
};
export type Device_createManualOtaOperation_MutationResponse = {
    readonly createManualOtaOperation: {
        readonly otaOperation: {
            readonly id: string;
            readonly baseImageUrl: string;
            readonly createdAt: string;
            readonly status: OtaOperationStatus;
            readonly statusCode: OtaOperationStatusCode | null;
            readonly updatedAt: string;
        };
    } | null;
};
export type Device_createManualOtaOperation_Mutation = {
    readonly response: Device_createManualOtaOperation_MutationResponse;
    readonly variables: Device_createManualOtaOperation_MutationVariables;
};



/*
mutation Device_createManualOtaOperation_Mutation(
  $input: CreateManualOtaOperationInput!
) {
  createManualOtaOperation(input: $input) {
    otaOperation {
      id
      baseImageUrl
      createdAt
      status
      statusCode
      updatedAt
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
    "concreteType": "CreateManualOtaOperationPayload",
    "kind": "LinkedField",
    "name": "createManualOtaOperation",
    "plural": false,
    "selections": [
      {
        "alias": null,
        "args": null,
        "concreteType": "OtaOperation",
        "kind": "LinkedField",
        "name": "otaOperation",
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
            "name": "baseImageUrl",
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "kind": "ScalarField",
            "name": "createdAt",
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "kind": "ScalarField",
            "name": "status",
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "kind": "ScalarField",
            "name": "statusCode",
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "kind": "ScalarField",
            "name": "updatedAt",
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
    "name": "Device_createManualOtaOperation_Mutation",
    "selections": (v1/*: any*/),
    "type": "RootMutationType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "Device_createManualOtaOperation_Mutation",
    "selections": (v1/*: any*/)
  },
  "params": {
    "cacheID": "08dbacce82b15631a95d22a63ac74442",
    "id": null,
    "metadata": {},
    "name": "Device_createManualOtaOperation_Mutation",
    "operationKind": "mutation",
    "text": "mutation Device_createManualOtaOperation_Mutation(\n  $input: CreateManualOtaOperationInput!\n) {\n  createManualOtaOperation(input: $input) {\n    otaOperation {\n      id\n      baseImageUrl\n      createdAt\n      status\n      statusCode\n      updatedAt\n    }\n  }\n}\n"
  }
};
})();
(node as any).hash = 'fe865fe5aac4b7a1f45a5e91229586b8';
export default node;
