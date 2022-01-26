/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ReaderFragment } from "relay-runtime";

import { FragmentRefs } from "relay-runtime";
export type Device_osBundle = {
    readonly osBundle: {
        readonly name: string | null;
        readonly version: string | null;
        readonly buildId: string | null;
        readonly fingerprint: string | null;
    } | null;
    readonly " $refType": "Device_osBundle";
};
export type Device_osBundle$data = Device_osBundle;
export type Device_osBundle$key = {
    readonly " $data"?: Device_osBundle$data | undefined;
    readonly " $fragmentRefs": FragmentRefs<"Device_osBundle">;
};



const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "Device_osBundle",
  "selections": [
    {
      "alias": null,
      "args": null,
      "concreteType": "OsBundle",
      "kind": "LinkedField",
      "name": "osBundle",
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
(node as any).hash = '5b8800b5c08c1b6281c3ec90f1ae492e';
export default node;
