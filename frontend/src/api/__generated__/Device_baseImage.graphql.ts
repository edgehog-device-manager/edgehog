/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ReaderFragment } from "relay-runtime";

import { FragmentRefs } from "relay-runtime";
export type Device_baseImage = {
    readonly baseImage: {
        readonly name: string | null;
        readonly version: string | null;
        readonly buildId: string | null;
        readonly fingerprint: string | null;
    } | null;
    readonly " $refType": "Device_baseImage";
};
export type Device_baseImage$data = Device_baseImage;
export type Device_baseImage$key = {
    readonly " $data"?: Device_baseImage$data | undefined;
    readonly " $fragmentRefs": FragmentRefs<"Device_baseImage">;
};



const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "Device_baseImage",
  "selections": [
    {
      "alias": null,
      "args": null,
      "concreteType": "BaseImage",
      "kind": "LinkedField",
      "name": "baseImage",
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
          "name": "buildId",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "fingerprint",
          "storageKey": null
        }
      ],
      "storageKey": null
    }
  ],
  "type": "Device",
  "abstractKey": null
};
(node as any).hash = 'c822701364fbd0df6ce87fc48896204b';
export default node;
