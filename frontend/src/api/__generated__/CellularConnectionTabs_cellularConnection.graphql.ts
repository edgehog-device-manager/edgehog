/**
 * @generated SignedSource<<4f77d49f9520b27afceccd91be5e0013>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { Fragment, ReaderFragment } from 'relay-runtime';
export type ModemRegistrationStatus = "NOT_REGISTERED" | "REGISTERED" | "SEARCHING_OPERATOR" | "REGISTRATION_DENIED" | "UNKNOWN" | "REGISTERED_ROAMING" | "%future added value";
export type ModemTechnology = "GSM" | "GSM_COMPACT" | "UTRAN" | "GSM_EGPRS" | "UTRAN_HSDPA" | "UTRAN_HSUPA" | "UTRAN_HSDPA_HSUPA" | "EUTRAN" | "%future added value";
import { FragmentRefs } from "relay-runtime";
export type CellularConnectionTabs_cellularConnection$data = {
  readonly cellularConnection: ReadonlyArray<{
    readonly apn: string | null;
    readonly carrier: string | null;
    readonly cellId: number | null;
    readonly imei: string | null;
    readonly imsi: string | null;
    readonly localAreaCode: number | null;
    readonly mobileCountryCode: number | null;
    readonly mobileNetworkCode: number | null;
    readonly registrationStatus: ModemRegistrationStatus | null;
    readonly rssi: number | null;
    readonly slot: string;
    readonly technology: ModemTechnology | null;
  }> | null;
  readonly " $fragmentType": "CellularConnectionTabs_cellularConnection";
};
export type CellularConnectionTabs_cellularConnection$key = {
  readonly " $data"?: CellularConnectionTabs_cellularConnection$data;
  readonly " $fragmentSpreads": FragmentRefs<"CellularConnectionTabs_cellularConnection">;
};

const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "CellularConnectionTabs_cellularConnection",
  "selections": [
    {
      "alias": null,
      "args": null,
      "concreteType": "Modem",
      "kind": "LinkedField",
      "name": "cellularConnection",
      "plural": true,
      "selections": [
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "apn",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "carrier",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "cellId",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "imei",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "imsi",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "localAreaCode",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "mobileCountryCode",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "mobileNetworkCode",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "registrationStatus",
          "storageKey": null
        },
        {
          "alias": null,
          "args": null,
          "kind": "ScalarField",
          "name": "rssi",
          "storageKey": null
        },
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
          "name": "technology",
          "storageKey": null
        }
      ],
      "storageKey": null
    }
  ],
  "type": "Device",
  "abstractKey": null
};

(node as any).hash = "792bcfb753ce4dbf1fd83ec96a9facdf";

export default node;
