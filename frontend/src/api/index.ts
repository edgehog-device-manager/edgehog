/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2025 SECO Mind Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import "@/api/relay";

import {
  Environment,
  Network,
  RecordSource,
  Store,
  Observable,
  TaskScheduler,
} from "relay-runtime";
import type {
  FetchFunction,
  Variables,
  UploadableMap,
  RequestParameters,
  SubscribeFunction,
} from "relay-runtime";

import ReactDOM from "react-dom";

import type { Session } from "@/contexts/Session";

// Phoenix WebSocket V2 message format types
type PhoenixJoinRef = string | null;
type PhoenixRef = string | null;
type PhoenixTopic = string;
type PhoenixEvent =
  | "phx_join"
  | "phx_leave"
  | "phx_reply"
  | "phx_close"
  | "phx_error"
  | "heartbeat"
  | "doc"
  | "message"
  | "subscription:data";

interface PhoenixPayload {
  status?: "ok" | "error";
  response?: {
    subscriptionId?: string;
    errors?: Array<{ message: string; locations?: unknown[]; path?: string[] }>;
    reason?: string;
    [key: string]: unknown;
  };
  result?: {
    data?: unknown;
    errors?: Array<{ message: string; locations?: unknown[]; path?: string[] }>;
  };
  subscriptionId?: string;
  [key: string]: unknown;
}

// Phoenix V2 WebSocket message: [join_ref, ref, topic, event, payload]
type PhoenixMessage = [
  PhoenixJoinRef,
  PhoenixRef,
  PhoenixTopic,
  PhoenixEvent,
  PhoenixPayload,
];

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

const createSubscribeFunction = (session: Session): SubscribeFunction => {
  return (operation: RequestParameters, variables: Variables) => {
    return Observable.create((sink) => {
      if (!session) return sink.error(new Error("No session"));

      const protocol = backendUrl.startsWith("https") ? "wss:" : "ws:";
      const url = new URL(
        "socket/websocket",
        backendUrl.replace(/^https?:/, protocol),
      );
      url.searchParams.set("vsn", "2.0.0");
      url.searchParams.set("token", session.authToken);
      url.searchParams.set("tenant", session.tenantSlug);

      const ws = new WebSocket(url.toString());

      let refCounter = 0;
      const topic = "__absinthe__:control";
      let heartbeat: number | undefined;
      let joinRef: string | null = null;

      interface SendParams {
        ref: PhoenixRef;
        topic: PhoenixTopic;
        event: PhoenixEvent;
        payload: PhoenixPayload;
      }

      const send = (
        ref: SendParams["ref"],
        topic: SendParams["topic"],
        event: SendParams["event"],
        payload: SendParams["payload"],
      ): void => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify([null, ref, topic, event, payload]));
        }
      };

      ws.onopen = () => {
        joinRef = String(++refCounter);
        send(joinRef, topic, "phx_join", {});

        heartbeat = setInterval(
          () => send(null, "phoenix", "heartbeat", {}),
          30000,
        );
      };

      ws.onmessage = (e) => {
        const [, msgRef, , event, payload]: PhoenixMessage = JSON.parse(e.data);

        if (
          event === "phx_reply" &&
          msgRef === joinRef &&
          payload.status === "ok"
        ) {
          const queryRef = String(++refCounter);
          send(queryRef, topic, "doc", {
            query: operation.text,
            variables,
          });
        } else if (
          event === "phx_reply" &&
          msgRef === joinRef &&
          payload.status === "error"
        ) {
          sink.error(
            new Error(
              `Channel join failed: ${JSON.stringify(payload.response)}`,
            ),
          );
        } else if (event === "subscription:data" && payload.result) {
          const result = payload.result;
          if (result.errors) {
            sink.error(new Error(JSON.stringify(result.errors)));
          } else {
            sink.next({ data: result.data as any, errors: [] });
          }
        }
      };

      ws.onerror = () => sink.error(new Error("WebSocket error"));

      return () => {
        if (heartbeat) clearInterval(heartbeat);
        if (ws.readyState < 2) ws.close();
      };
    });
  };
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

  const subscribeRelay = createSubscribeFunction(session);

  return new Environment({
    network: Network.create(fetchRelay, subscribeRelay),
    store: new Store(new RecordSource()),
    scheduler: relayScheduler,
  });
};

export type { FetchGraphQL };
export { fetchGraphQL, relayEnvironment };
