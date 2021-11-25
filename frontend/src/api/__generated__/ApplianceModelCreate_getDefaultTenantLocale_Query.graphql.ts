/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type ApplianceModelCreate_getDefaultTenantLocale_QueryVariables = {};
export type ApplianceModelCreate_getDefaultTenantLocale_QueryResponse = {
    readonly tenantInfo: {
        readonly defaultLocale: string;
    };
};
export type ApplianceModelCreate_getDefaultTenantLocale_Query = {
    readonly response: ApplianceModelCreate_getDefaultTenantLocale_QueryResponse;
    readonly variables: ApplianceModelCreate_getDefaultTenantLocale_QueryVariables;
};



/*
query ApplianceModelCreate_getDefaultTenantLocale_Query {
  tenantInfo {
    defaultLocale
  }
}
*/

const node: ConcreteRequest = (function(){
var v0 = [
  {
    "alias": null,
    "args": null,
    "concreteType": "TenantInfo",
    "kind": "LinkedField",
    "name": "tenantInfo",
    "plural": false,
    "selections": [
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "defaultLocale",
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
    "name": "ApplianceModelCreate_getDefaultTenantLocale_Query",
    "selections": (v0/*: any*/),
    "type": "RootQueryType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": [],
    "kind": "Operation",
    "name": "ApplianceModelCreate_getDefaultTenantLocale_Query",
    "selections": (v0/*: any*/)
  },
  "params": {
    "cacheID": "64cd0dd038346ffc39a72069a1d95aff",
    "id": null,
    "metadata": {},
    "name": "ApplianceModelCreate_getDefaultTenantLocale_Query",
    "operationKind": "query",
    "text": "query ApplianceModelCreate_getDefaultTenantLocale_Query {\n  tenantInfo {\n    defaultLocale\n  }\n}\n"
  }
};
})();
(node as any).hash = '5a9124a99f887191bc9a57343e64422a';
export default node;
