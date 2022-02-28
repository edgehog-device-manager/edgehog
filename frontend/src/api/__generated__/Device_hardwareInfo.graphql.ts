/**
 * @generated SignedSource<<0a1c6f78c922c0c51f31c2920dd950c9>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { Fragment, ReaderFragment } from 'relay-runtime';
import { FragmentRefs } from "relay-runtime";
export type Device_hardwareInfo$data = {
  readonly hardwareInfo: {
    readonly cpuArchitecture: string | null;
    readonly cpuModel: string | null;
    readonly cpuModelName: string | null;
    readonly cpuVendor: string | null;
    readonly memoryTotalBytes: number | null;
  } | null;
  readonly " $fragmentType": "Device_hardwareInfo";
};
export type Device_hardwareInfo$key = {
  readonly " $data"?: Device_hardwareInfo$data;
  readonly " $fragmentSpreads": FragmentRefs<"Device_hardwareInfo">;
};

const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "Device_hardwareInfo",
  "selections": [
    {
      "alias": null,
      "args": null,
      "concreteType": "HardwareInfo",
      "kind": "LinkedField",
      "name": "hardwareInfo",
      "plural": false,
      "selections": [
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "cpuArchitecture",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "cpuModel",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "cpuModelName",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "cpuVendor",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "memoryTotalBytes",
          "storageKey": null
        }
      ],
      "storageKey": null
    }
  ],
  "type": "Device",
  "abstractKey": null
};

(node as any).hash = "85fb3bea9e82e044d5a70ab7a5fd3bcb";

export default node;
