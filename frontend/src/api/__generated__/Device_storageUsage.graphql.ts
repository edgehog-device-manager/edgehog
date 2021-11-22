/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ReaderFragment } from "relay-runtime";

import { FragmentRefs } from "relay-runtime";
export type Device_storageUsage = {
    readonly storageUsage: ReadonlyArray<{
        readonly label: string;
        readonly totalBytes: number | null;
        readonly freeBytes: number | null;
    }> | null;
    readonly " $refType": "Device_storageUsage";
};
export type Device_storageUsage$data = Device_storageUsage;
export type Device_storageUsage$key = {
    readonly " $data"?: Device_storageUsage$data | undefined;
    readonly " $fragmentRefs": FragmentRefs<"Device_storageUsage">;
};



const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "Device_storageUsage",
  "selections": [
    {
      "alias": null,
      "args": null,
      "concreteType": "StorageUnit",
      "kind": "LinkedField",
      "name": "storageUsage",
      "plural": true,
      "selections": [
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "label",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "totalBytes",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "freeBytes",
          "storageKey": null
        }
      ],
      "storageKey": null
    }
  ],
  "type": "Device",
  "abstractKey": null
};
(node as any).hash = '6869a83bfcf699299226ebc744289ed6';
export default node;
