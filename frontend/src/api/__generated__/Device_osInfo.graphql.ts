/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ReaderFragment } from "relay-runtime";

import { FragmentRefs } from "relay-runtime";
export type Device_osInfo = {
    readonly osInfo: {
        readonly name: string | null;
        readonly version: string | null;
    } | null;
    readonly " $refType": "Device_osInfo";
};
export type Device_osInfo$data = Device_osInfo;
export type Device_osInfo$key = {
    readonly " $data"?: Device_osInfo$data | undefined;
    readonly " $fragmentRefs": FragmentRefs<"Device_osInfo">;
};



const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "Device_osInfo",
  "selections": [
    {
      "alias": null,
      "args": null,
      "concreteType": "OsInfo",
      "kind": "LinkedField",
      "name": "osInfo",
      "plural": false,
      "selections": [
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
          "name": "version",
          "storageKey": null
        }
      ],
      "storageKey": null
    }
  ],
  "type": "Device",
  "abstractKey": null
};
(node as any).hash = 'e6ebd58bb4a895bdb6a29c499c830024';
export default node;
