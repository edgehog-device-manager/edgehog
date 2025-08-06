/*
  This file is part of Edgehog.

  Copyright 2021-2025 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import "api/relay";
import { Environment, Network, RecordSource, Store } from "relay-runtime";
import type { FetchFunction, Variables, UploadableMap } from "relay-runtime";
import type { TaskScheduler } from "relay-runtime";
import ReactDOM from "react-dom";

import type { Session } from "contexts/Session";

const applicationMetatag: HTMLElement = document.head.querySelector(
  "[name=application-name]",
)!;
const backendUrl =
  applicationMetatag.dataset?.backendUrl || "http://localhost:4000";

try {
  new URL(backendUrl);
} catch {
  console.error(
    `An invalid Edgehog backend API base URL has been specified.
Please ensure that the 'BACKEND_URL' environment variable contains schema, e.g. 'https://api.edgehog.localhost'`,
  );
}

const fetchGraphQL = async (
  query: string | null | undefined,
  variables: Record<string, unknown>,
  tenantSlug: string,
  authToken: string,
) => {
  const userLanguage = navigator.language; // TODO allow users to overwrite this
  const apiUrl = new URL(`tenants/${tenantSlug}/api`, backendUrl);
  const response = await fetch(apiUrl.toString(), {
    method: "POST",
    headers: {
      Authorization: `Bearer ${authToken}`,
      "Content-Type": "application/json",
      "Accept-Language": userLanguage,
    },
    body: JSON.stringify({ query, variables }),
  });
  return await response.json();
};
type FetchGraphQL = typeof fetchGraphQL;

const uploadGraphQL = async (
  query: string | null | undefined,
  variables: Record<string, unknown>,
  uploadables: UploadableMap,
  tenantSlug: string,
  authToken: string,
) => {
  const apiUrl = new URL(`tenants/${tenantSlug}/api`, backendUrl);
  const request: RequestInit = {
    method: "POST",
    headers: {
      Authorization: `Bearer ${authToken}`,
    },
  };
  const formData = new FormData();
  Object.entries(uploadables).forEach(([key, file]) => {
    formData.append(key, file);
  });
  formData.append("query", query!);
  formData.append("variables", JSON.stringify(variables));
  request.body = formData;
  const response = await fetch(apiUrl.toString(), request);
  return await response.json();
};

const extractUploadables = (
  initVariables: Variables,
): {
  variables: Variables;
  uploadables?: Record<string, File>;
} => {
  const variables: Variables = {};
  let uploadables: Record<string, File> | undefined = undefined;
  Object.entries(initVariables).forEach(([key, value]) => {
    if (value instanceof File) {
      variables[key] = key;
      uploadables = {
        ...(uploadables || {}),
        [key]: value,
      };
    } else if (
      typeof value === "object" &&
      !Array.isArray(value) &&
      value !== null
    ) {
      const extracted = extractUploadables(value);
      variables[key] = extracted.variables;
      if (extracted.uploadables) {
        uploadables = {
          ...(uploadables || {}),
          ...extracted.uploadables,
        };
      }
    } else {
      variables[key] = value;
    }
  });
  return { variables, uploadables };
};

// TODO: remove custom scheduler when Relay starts to use React's batched updates
// learn more: https://github.com/facebook/relay/issues/3514#issuecomment-988303222
const relayScheduler: TaskScheduler = {
  cancel: () => {},
  schedule: (task) => {
    ReactDOM.unstable_batchedUpdates(task);
    return "";
  },
};

const relayEnvironment = (session: Session) => {
  const fetchRelay: FetchFunction = async (
    operation,
    variables,
    _cacheConfig,
    _uploadables,
  ) => {
    if (!session) {
      throw new Error("Session is null");
    }

    const extracted = extractUploadables(variables);
    return extracted.uploadables
      ? await uploadGraphQL(
          operation.text,
          extracted.variables,
          extracted.uploadables,
          session.tenantSlug,
          session.authToken,
        )
      : await fetchGraphQL(
          operation.text,
          variables,
          session.tenantSlug,
          session.authToken,
        );
  };

  return new Environment({
    network: Network.create(fetchRelay),
    store: new Store(new RecordSource()),
    scheduler: relayScheduler,
  });
};

export type { FetchGraphQL };
export { fetchGraphQL, relayEnvironment };
