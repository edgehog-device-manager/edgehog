/**
 * @generated SignedSource<<2d913426c4e4dddf6a00668accfc7a29>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { Fragment, ReaderFragment } from 'relay-runtime';
export type BatteryStatus = "CHARGING" | "DISCHARGING" | "IDLE" | "EITHER_IDLE_OR_CHARGING" | "FAILURE" | "REMOVED" | "UNKNOWN" | "%future added value";
import { FragmentRefs } from "relay-runtime";
export type Device_batteryStatus$data = {
  readonly batteryStatus: ReadonlyArray<{
    readonly slot: string;
    readonly status: BatteryStatus | null;
    readonly levelPercentage: number | null;
    readonly levelAbsoluteError: number | null;
  }> | null;
  readonly " $fragmentType": "Device_batteryStatus";
};
export type Device_batteryStatus$key = {
  readonly " $data"?: Device_batteryStatus$data;
  readonly " $fragmentSpreads": FragmentRefs<"Device_batteryStatus">;
};

const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "Device_batteryStatus",
  "selections": [
    {
      "alias": null,
      "args": null,
      "concreteType": "BatterySlot",
      "kind": "LinkedField",
      "name": "batteryStatus",
      "plural": true,
      "selections": [
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "slot",
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
          "name": "levelPercentage",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "levelAbsoluteError",
          "storageKey": null
        }
      ],
      "storageKey": null
    }
  ],
  "type": "Device",
  "abstractKey": null
};

(node as any).hash = "1d8b5a898b7e23df67c98f4d88993a3a";

export default node;
