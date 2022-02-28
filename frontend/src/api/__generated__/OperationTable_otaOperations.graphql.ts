/**
 * @generated SignedSource<<282508f083ca32036cfe49cab7b2601b>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { Fragment, ReaderFragment } from 'relay-runtime';
export type OtaOperationStatus = "PENDING" | "IN_PROGRESS" | "ERROR" | "DONE" | "%future added value";
import { FragmentRefs } from "relay-runtime";
export type OperationTable_otaOperations$data = {
  readonly otaOperations: ReadonlyArray<{
    readonly baseImageUrl: string;
    readonly createdAt: string;
    readonly status: OtaOperationStatus;
    readonly updatedAt: string;
  }>;
  readonly " $fragmentType": "OperationTable_otaOperations";
};
export type OperationTable_otaOperations$key = {
  readonly " $data"?: OperationTable_otaOperations$data;
  readonly " $fragmentSpreads": FragmentRefs<"OperationTable_otaOperations">;
};

const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "OperationTable_otaOperations",
  "selections": [
    {
      "alias": null,
      "args": null,
      "concreteType": "OtaOperation",
      "kind": "LinkedField",
      "name": "otaOperations",
      "plural": true,
      "selections": [
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

(node as any).hash = "b9472c4144df80a20fe6b71ef36ec340";

export default node;
