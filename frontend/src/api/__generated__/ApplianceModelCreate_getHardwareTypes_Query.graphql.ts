/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type ApplianceModelCreate_getHardwareTypes_QueryVariables = {};
export type ApplianceModelCreate_getHardwareTypes_QueryResponse = {
    readonly hardwareTypes: ReadonlyArray<{
        readonly id: string;
        readonly name: string;
    }>;
};
export type ApplianceModelCreate_getHardwareTypes_Query = {
    readonly response: ApplianceModelCreate_getHardwareTypes_QueryResponse;
    readonly variables: ApplianceModelCreate_getHardwareTypes_QueryVariables;
};



/*
query ApplianceModelCreate_getHardwareTypes_Query {
  hardwareTypes {
    id
    name
  }
}
*/

const node: ConcreteRequest = (function(){
var v0 = [
  {
    "alias": null,
    "args": null,
    "concreteType": "HardwareType",
    "kind": "LinkedField",
    "name": "hardwareTypes",
    "plural": true,
    "selections": [
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "id",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "name",
        "storageKey": null
      }
    ],
    "storageKey": null
  }
];
return {
  "fragment": {
    "argumentDefinitions": [],
    "kind": "Fragment",
    "metadata": null,
    "name": "ApplianceModelCreate_getHardwareTypes_Query",
    "selections": (v0/*: any*/),
    "type": "RootQueryType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": [],
    "kind": "Operation",
    "name": "ApplianceModelCreate_getHardwareTypes_Query",
    "selections": (v0/*: any*/)
  },
  "params": {
    "cacheID": "61d6ac6911c0daa47c3cbc827190d666",
    "id": null,
    "metadata": {},
    "name": "ApplianceModelCreate_getHardwareTypes_Query",
    "operationKind": "query",
    "text": "query ApplianceModelCreate_getHardwareTypes_Query {\n  hardwareTypes {\n    id\n    name\n  }\n}\n"
  }
};
})();
(node as any).hash = '548a070dc1e3db501ad4dbdd7ac90c94';
export default node;
