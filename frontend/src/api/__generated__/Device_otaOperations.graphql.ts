/**
 * @generated SignedSource<<2463a00d6c872a82cb91dac3d5d6214d>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { Fragment, ReaderFragment } from 'relay-runtime';
export type OtaOperationStatus = "PENDING" | "IN_PROGRESS" | "ERROR" | "DONE" | "%future added value";
import { FragmentRefs } from "relay-runtime";
export type Device_otaOperations$data = {
  readonly id: string;
  readonly otaOperations: ReadonlyArray<{
    readonly id: string;
    readonly baseImageUrl: string;
    readonly status: OtaOperationStatus;
  }>;
  readonly " $fragmentSpreads": FragmentRefs<"OperationTable_otaOperations">;
  readonly " $fragmentType": "Device_otaOperations";
};
export type Device_otaOperations$key = {
  readonly " $data"?: Device_otaOperations$data;
  readonly " $fragmentSpreads": FragmentRefs<"Device_otaOperations">;
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
          "name": "status",
          "storageKey": null
        }
      ],
      "storageKey": null
    },
    {
      "args": null,
      "kind": "FragmentSpread",
      "name": "OperationTable_otaOperations"
    }
  ],
  "type": "Device",
  "abstractKey": null
};
})();

(node as any).hash = "2f353b925a526bae9772035ab80c4cb1";

export default node;
