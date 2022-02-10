/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ReaderFragment } from "relay-runtime";

import { FragmentRefs } from "relay-runtime";
export type ModemRegistrationStatus = "NOT_REGISTERED" | "REGISTERED" | "REGISTERED_ROAMING" | "REGISTRATION_DENIED" | "SEARCHING_OPERATOR" | "UNKNOWN" | "%future added value";
export type ModemTechnology = "EUTRAN" | "GSM" | "GSM_COMPACT" | "GSM_EGPRS" | "UTRAN" | "UTRAN_HSDPA" | "UTRAN_HSDPA_HSUPA" | "UTRAN_HSUPA" | "%future added value";
export type CellularConnectionTabs_cellularConnection = {
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
    readonly " $refType": "CellularConnectionTabs_cellularConnection";
};
export type CellularConnectionTabs_cellularConnection$data = CellularConnectionTabs_cellularConnection;
export type CellularConnectionTabs_cellularConnection$key = {
    readonly " $data"?: CellularConnectionTabs_cellularConnection$data | undefined;
    readonly " $fragmentRefs": FragmentRefs<"CellularConnectionTabs_cellularConnection">;
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
(node as any).hash = '792bcfb753ce4dbf1fd83ec96a9facdf';
export default node;
