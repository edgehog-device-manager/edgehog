/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest } from "relay-runtime";

export type ApplianceModel_getDefaultTenantLocale_QueryVariables = {};
export type ApplianceModel_getDefaultTenantLocale_QueryResponse = {
    readonly tenantInfo: {
        readonly defaultLocale: string;
    };
};
export type ApplianceModel_getDefaultTenantLocale_Query = {
    readonly response: ApplianceModel_getDefaultTenantLocale_QueryResponse;
    readonly variables: ApplianceModel_getDefaultTenantLocale_QueryVariables;
};



/*
query ApplianceModel_getDefaultTenantLocale_Query {
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
    "name": "ApplianceModel_getDefaultTenantLocale_Query",
    "selections": (v0/*: any*/),
    "type": "RootQueryType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": [],
    "kind": "Operation",
    "name": "ApplianceModel_getDefaultTenantLocale_Query",
    "selections": (v0/*: any*/)
  },
  "params": {
    "cacheID": "69ea4bed93ebabd0cec9eb42307ebe0c",
    "id": null,
    "metadata": {},
    "name": "ApplianceModel_getDefaultTenantLocale_Query",
    "operationKind": "query",
    "text": "query ApplianceModel_getDefaultTenantLocale_Query {\n  tenantInfo {\n    defaultLocale\n  }\n}\n"
  }
};
})();
(node as any).hash = '10e988c360e4f85a2192cbeec5f1cf4d';
export default node;
