/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ReaderFragment } from "relay-runtime";

import { FragmentRefs } from "relay-runtime";
export type Device_systemStatus = {
    readonly systemStatus: {
        readonly memoryFreeBytes: number | null;
        readonly taskCount: number | null;
        readonly uptimeMilliseconds: number | null;
        readonly timestamp: string;
    } | null;
    readonly " $refType": "Device_systemStatus";
};
export type Device_systemStatus$data = Device_systemStatus;
export type Device_systemStatus$key = {
    readonly " $data"?: Device_systemStatus$data | undefined;
    readonly " $fragmentRefs": FragmentRefs<"Device_systemStatus">;
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
(node as any).hash = 'ab9e157d7347e816501bd102a081ae62';
export default node;
