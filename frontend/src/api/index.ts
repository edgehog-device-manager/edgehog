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
import {
  Environment,
  Network,
  RecordSource,
  Store,
  Observable,
} from "relay-runtime";
import type {
  FetchFunction,
  Variables,
  UploadableMap,
  RequestParameters,
  SubscribeFunction,
} from "relay-runtime";
import type { TaskScheduler } from "relay-runtime";
import ReactDOM from "react-dom";

import type { Session } from "contexts/Session";

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
  | "subscription:data";

interface PhoenixPayload {
  status?: "ok" | "error";
  response?: {
    subscriptionId?: string;
    errors?: Array<{ message: string; locations?: unknown[]; path?: string[] }>;
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
      if (!session) {
        sink.error(new Error("Session is null"));
        return;
      }

      const wsProtocol = backendUrl.startsWith("https") ? "wss" : "ws";
      const wsBaseUrl = backendUrl.replace(/^https?:/, wsProtocol + ":");
      const wsUrl = new URL(
        `tenants/${session.tenantSlug}/socket/websocket`,
        wsBaseUrl,
      );
      wsUrl.searchParams.set("vsn", "2.0.0");
      wsUrl.searchParams.set("Authorization", `Bearer ${session.authToken}`);
      wsUrl.searchParams.set("tenant", session.tenantSlug);

      const socket = new WebSocket(wsUrl.toString());
      const refId = () => Math.random().toString(36).substring(7);
      let heartbeat: number | null = null;
      let topic: string | null = null;

      const send = (ref: string, event: PhoenixEvent, payload: PhoenixPayload = {}) =>
        socket.send(JSON.stringify([null, ref, "__absinthe__:control", event, payload]));

      socket.onopen = () => {
        heartbeat = setInterval(() => {
          if (socket.readyState === WebSocket.OPEN) {
            socket.send(JSON.stringify([null, refId(), "phoenix", "heartbeat", {}]));
          }
        }, 30000);

        send("1", "phx_join");
      };

      socket.onmessage = (event) => {
        const [, ref, , eventName, payload]: PhoenixMessage = JSON.parse(event.data);

        if (eventName === "phx_reply" && ref === "1" && payload.status === "ok") {
          send("2", "doc", { query: operation.text, variables });
        } else if (eventName === "phx_reply" && ref === "2") {
          if (payload.status === "ok" && payload.response?.subscriptionId) {
            topic = payload.response.subscriptionId;
            socket.send(JSON.stringify([null, "3", topic, "phx_join", {}]));
          } else {
            sink.error(new Error(JSON.stringify(payload.response?.errors || "Subscription failed")));
          }
        } else if (eventName === "subscription:data") {
          const data = payload.result;
          if (data?.errors) {
            sink.error(new Error(JSON.stringify(data.errors)));
          } else if (data?.data) {
            sink.next({ data: data.data as Record<string, unknown>, errors: [] });
          }
        } else if (eventName === "phx_close") {
          sink.complete();
        }
      };

      socket.onerror = () => sink.error(new Error("WebSocket connection error"));

      socket.onclose = (event) => {
        if (heartbeat) clearInterval(heartbeat);
        if (!event.wasClean && event.code !== 1000) {
          sink.error(new Error(event.reason || `Connection closed (${event.code})`));
        } else {
          sink.complete();
        }
      };

      return () => {
        if (heartbeat) clearInterval(heartbeat);
        if (socket.readyState === WebSocket.OPEN) {
          if (topic) socket.send(JSON.stringify([null, refId(), topic, "phx_leave", {}]));
          send(refId(), "phx_leave");
        }
        if (socket.readyState !== WebSocket.CLOSED && socket.readyState !== WebSocket.CLOSING) {
          socket.close(1000);
        }
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
