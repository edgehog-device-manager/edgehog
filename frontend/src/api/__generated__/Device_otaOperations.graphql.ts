/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ReaderFragment } from "relay-runtime";

import { FragmentRefs } from "relay-runtime";
export type OtaOperationStatus = "DONE" | "ERROR" | "IN_PROGRESS" | "PENDING" | "%future added value";
export type OtaOperationStatusCode = "ALREADY_IN_PROGRESS" | "DEPLOY_ERROR" | "FAILED" | "NETWORK_ERROR" | "NVS_ERROR" | "WRONG_PARTITION" | "%future added value";
export type Device_otaOperations = {
    readonly id: string;
    readonly otaOperations: ReadonlyArray<{
        readonly id: string;
        readonly baseImageUrl: string;
        readonly createdAt: string;
        readonly status: OtaOperationStatus;
        readonly statusCode: OtaOperationStatusCode | null;
        readonly updatedAt: string;
    }>;
    readonly " $refType": "Device_otaOperations";
};
export type Device_otaOperations$data = Device_otaOperations;
export type Device_otaOperations$key = {
    readonly " $data"?: Device_otaOperations$data | undefined;
    readonly " $fragmentRefs": FragmentRefs<"Device_otaOperations">;
};



const node: ReaderFragment = (function(){
var v0 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "id",
  "storageKey": null
};
return {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "Device_otaOperations",
  "selections": [
    (v0/*: any*/),
    {
      "alias": null,
      "args": null,
      "concreteType": "OtaOperation",
      "kind": "LinkedField",
      "name": "otaOperations",
      "plural": true,
      "selections": [
        (v0/*: any*/),
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
  "type": "Device",
  "abstractKey": null
};
})();
(node as any).hash = 'e6dac6089916b1e4b0bc8d5ea191a58b';
export default node;
