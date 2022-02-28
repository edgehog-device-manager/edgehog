/**
 * @generated SignedSource<<2b3c610f35af3f141b8534445b9abc12>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Query } from 'relay-runtime';
export type SystemModel_getDefaultTenantLocale_Query$variables = {};
export type SystemModel_getDefaultTenantLocale_Query$data = {
  readonly tenantInfo: {
    readonly defaultLocale: string;
  };
};
export type SystemModel_getDefaultTenantLocale_Query = {
  variables: SystemModel_getDefaultTenantLocale_Query$variables;
  response: SystemModel_getDefaultTenantLocale_Query$data;
};

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
    "name": "SystemModel_getDefaultTenantLocale_Query",
    "selections": (v0/*: any*/),
    "type": "RootQueryType",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": [],
    "kind": "Operation",
    "name": "SystemModel_getDefaultTenantLocale_Query",
    "selections": (v0/*: any*/)
  },
  "params": {
    "cacheID": "5ac7ba68b5f0628b821a65ff7b010e85",
    "id": null,
    "metadata": {},
    "name": "SystemModel_getDefaultTenantLocale_Query",
    "operationKind": "query",
    "text": "query SystemModel_getDefaultTenantLocale_Query {\n  tenantInfo {\n    defaultLocale\n  }\n}\n"
  }
};
})();

(node as any).hash = "57cda6d9aaf7a1db73d427cfacff8ca6";

export default node;
