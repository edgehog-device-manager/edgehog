/**
 * @generated SignedSource<<934d984bdab8018afcf2a80f940490b8>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { Fragment, ReaderFragment } from 'relay-runtime';
import { FragmentRefs } from "relay-runtime";
export type Device_systemStatus$data = {
  readonly systemStatus: {
    readonly memoryFreeBytes: number | null;
    readonly taskCount: number | null;
    readonly uptimeMilliseconds: number | null;
    readonly timestamp: string;
  } | null;
  readonly " $fragmentType": "Device_systemStatus";
};
export type Device_systemStatus$key = {
  readonly " $data"?: Device_systemStatus$data;
  readonly " $fragmentSpreads": FragmentRefs<"Device_systemStatus">;
};

const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "Device_systemStatus",
  "selections": [
    {
      "alias": null,
      "args": null,
      "concreteType": "SystemStatus",
      "kind": "LinkedField",
      "name": "systemStatus",
      "plural": false,
      "selections": [
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "memoryFreeBytes",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "taskCount",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "uptimeMilliseconds",
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

(node as any).hash = "ab9e157d7347e816501bd102a081ae62";

export default node;
