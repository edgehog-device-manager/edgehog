/**
 * @generated SignedSource<<d5914ae09c006814f27515bacbc0c137>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { Fragment, ReaderFragment } from 'relay-runtime';
import { FragmentRefs } from "relay-runtime";
export type Device_location$data = {
  readonly location: {
    readonly latitude: number;
    readonly longitude: number;
    readonly accuracy: number | null;
    readonly address: string | null;
    readonly timestamp: string;
  } | null;
  readonly " $fragmentType": "Device_location";
};
export type Device_location$key = {
  readonly " $data"?: Device_location$data;
  readonly " $fragmentSpreads": FragmentRefs<"Device_location">;
};

const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "Device_location",
  "selections": [
    {
      "alias": null,
      "args": null,
      "concreteType": "DeviceLocation",
      "kind": "LinkedField",
      "name": "location",
      "plural": false,
      "selections": [
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "latitude",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "longitude",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "accuracy",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "address",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "timestamp",
          "storageKey": null
        }
      ],
      "storageKey": null
    }
  ],
  "type": "Device",
  "abstractKey": null
};

(node as any).hash = "9c66b54eaa55ef5e02d1bfc5eb43707e";

export default node;
