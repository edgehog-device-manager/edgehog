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

      const endpoints = [
        `socket/websocket?vsn=2.0.0`,
        `tenants/${session.tenantSlug}/socket/websocket?vsn=2.0.0`,
        `api/socket/websocket?vsn=2.0.0`,
      ];

      const wsProtocol = backendUrl.startsWith("https") ? "wss" : "ws";
      const wsBaseUrl = backendUrl.replace(/^https?:/, wsProtocol + ":");

      const wsUrl = new URL(endpoints[0], wsBaseUrl).toString();

      console.log("Connecting to WebSocket:", wsUrl);

      const socket = new WebSocket(wsUrl);
      const subscriptionId = Math.random().toString(36).substring(7);
      let channelJoined = false;
      let subscriptionTopic: string | null = null;
      let heartbeatInterval: number | null = null;

      socket.onopen = () => {
        console.log("WebSocket opened successfully");

        // Start heartbeat - Phoenix V2 format: [join_ref, ref, topic, event, payload]
        heartbeatInterval = setInterval(() => {
          if (socket.readyState === WebSocket.OPEN) {
            socket.send(
              JSON.stringify([
                null,
                Date.now().toString(),
                "phoenix",
                "heartbeat",
                {},
              ]),
            );
          }
        }, 30000);

        // Join the __absinthe__:control channel - Phoenix V2 format
        socket.send(
          JSON.stringify([null, "1", "__absinthe__:control", "phx_join", {}]),
        );
      };

      socket.onmessage = (event) => {
        const message: PhoenixMessage = JSON.parse(event.data);
        console.log("WebSocket message received:", message);

        // Phoenix V2 format: [join_ref, ref, topic, event, payload]
        const [, ref, topic, eventName, payload] = message;

        // Handle heartbeat responses
        if (
          eventName === "phx_reply" &&
          ref &&
          ref !== "1" &&
          ref !== subscriptionId
        ) {
          return;
        }

        // Handle channel join reply
        if (
          topic === "__absinthe__:control" &&
          eventName === "phx_reply" &&
          ref === "1"
        ) {
          if (payload.status === "ok") {
            console.log("Channel joined successfully");
            channelJoined = true;

            // Send the subscription request
            socket.send(
              JSON.stringify([
                null,
                subscriptionId,
                "__absinthe__:control",
                "doc",
                {
                  query: operation.text,
                  variables: variables,
                },
              ]),
            );
          } else {
            console.error("Channel join failed:", payload);
            const errorMsg = payload.response?.errors
              ? JSON.stringify(payload.response.errors)
              : "Channel join failed";
            sink.error(new Error(errorMsg));
          }
        }

        // Handle subscription response
        if (ref === subscriptionId && eventName === "phx_reply") {
          if (payload.status === "ok") {
            subscriptionTopic = payload.response?.subscriptionId ?? null;
            console.log("Subscription created:", subscriptionTopic);

            if (subscriptionTopic) {
              socket.send(
                JSON.stringify([
                  null,
                  subscriptionId + "_join",
                  subscriptionTopic,
                  "phx_join",
                  {},
                ]),
              );
            }
          } else {
            console.error("Subscription failed:", payload);
            const errorMsg = payload.response?.errors
              ? JSON.stringify(payload.response.errors)
              : "Subscription failed";
            sink.error(new Error(errorMsg));
          }
        }

        // Handle subscription data
        if (eventName === "subscription:data") {
          console.log("Subscription data received:", payload);
          const data = payload.result;
          if (data?.errors) {
            sink.error(new Error(JSON.stringify(data.errors)));
          } else if (data?.data) {
            sink.next({
              data: data.data as Record<string, unknown>,
              errors: [],
            });
          }
        }

        // Handle completion
        if (eventName === "phx_close") {
          console.log("Subscription closed by server");
          sink.complete();
        }
      };

      socket.onerror = (error) => {
        console.error("WebSocket error occurred:", error);
        sink.error(new Error("WebSocket connection error"));
      };

      socket.onclose = (event) => {
        console.log("WebSocket closed:", {
          code: event.code,
          reason: event.reason,
          wasClean: event.wasClean,
          url: wsUrl,
        });

        if (heartbeatInterval) {
          clearInterval(heartbeatInterval);
        }

        const closeReasons: Record<number, string> = {
          1000: "Normal closure",
          1006: "Abnormal closure - connection lost before handshake",
          1008: "Policy violation - likely authentication failure",
          1011: "Server error - backend rejected the connection",
        };

        const reason =
          closeReasons[event.code] || `Unknown close code ${event.code}`;
        console.log(`Close reason: ${reason}`);

        if (!event.wasClean && event.code !== 1000) {
          const errorMsg = event.reason || reason;
          sink.error(new Error(errorMsg));
        } else {
          sink.complete();
        }
      };

      return () => {
        console.log("Cleaning up WebSocket subscription");

        if (heartbeatInterval) {
          clearInterval(heartbeatInterval);
        }

        if (socket.readyState === WebSocket.OPEN) {
          if (subscriptionTopic) {
            socket.send(
              JSON.stringify([
                null,
                subscriptionId + "_leave_sub",
                subscriptionTopic,
                "phx_leave",
                {},
              ]),
            );
          }

          if (channelJoined) {
            socket.send(
              JSON.stringify([
                null,
                subscriptionId + "_leave",
                "__absinthe__:control",
                "phx_leave",
                {},
              ]),
            );
          }
        }

        if (
          socket.readyState !== WebSocket.CLOSED &&
          socket.readyState !== WebSocket.CLOSING
        ) {
          socket.close(1000, "Client closing subscription");
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
