/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ReaderFragment } from "relay-runtime";

import { FragmentRefs } from "relay-runtime";
export type Device_runtimeInfo = {
    readonly runtimeInfo: {
        readonly name: string | null;
        readonly version: string | null;
        readonly environment: string | null;
        readonly url: string | null;
    } | null;
    readonly " $refType": "Device_runtimeInfo";
};
export type Device_runtimeInfo$data = Device_runtimeInfo;
export type Device_runtimeInfo$key = {
    readonly " $data"?: Device_runtimeInfo$data | undefined;
    readonly " $fragmentRefs": FragmentRefs<"Device_runtimeInfo">;
};



const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "Device_runtimeInfo",
  "selections": [
    {
      "alias": null,
      "args": null,
      "concreteType": "RuntimeInfo",
      "kind": "LinkedField",
      "name": "runtimeInfo",
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
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "environment",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "url",
          "storageKey": null
        }
      ],
      "storageKey": null
    }
  ],
  "type": "Device",
  "abstractKey": null
};
(node as any).hash = '5061d4cb055220fa943b63060cf47dfe';
export default node;
