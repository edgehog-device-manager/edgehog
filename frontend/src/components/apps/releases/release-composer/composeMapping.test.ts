/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import { describe, expect, it } from "vitest";
import { parse } from "yaml";

import {
  composeToFormData,
  formDataToCompose,
  type MappingContext,
} from "./composeMapping";

const context: MappingContext = {
  networkOptions: [
    { label: "frontend-net", value: "network-1" },
    { label: "backend-net", value: "network-2" },
  ],
  volumeOptions: [{ label: "app-data", value: "volume-1" }],
};

describe("composeToFormData", () => {
  it("parses a full compose file", () => {
    const yaml = `
services:
  web:
    image: nginx:1.27
    hostname: web.local
    restart: unless-stopped
    privileged: true
    read_only: true
    ports:
      - "8080:80"
    environment:
      DEBUG: "true"
      PORT: 8080
    extra_hosts:
      - "db-host:192.168.1.10"
    networks:
      - frontend-net
    tmpfs:
      - /tmp
    cap_add:
      - CAP_NET_ADMIN
    mem_limit: 512m
    cpu_quota: 50000
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0:rwm
    depends_on:
      - api
  api:
    image: myorg/api:2.0.0
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    expect(result.warnings).toEqual([]);
    expect(result.data.services).toHaveLength(2);

    const web = result.data.services[0];

    expect(web.name).toBe("web");
    expect(web.container.image?.reference).toBe("nginx:1.27");
    expect(web.container.restartPolicy).toBe("unless_stopped");
    expect(web.container.privileged).toBe(true);
    expect(web.container.readOnlyRootfs).toBe(true);
    expect(web.container.portBindings).toEqual(["8080:80"]);
    expect(web.container.env).toEqual([
      { key: "DEBUG", value: "true" },
      { key: "PORT", value: "8080" },
    ]);
    expect(web.container.networks).toEqual([{ id: "network-1" }]);
    expect(web.container.memory).toBe(512 * 1024 ** 2);
    expect(web.container.cpuQuota).toBe(50000);
    expect(web.container.deviceMappings).toEqual([
      {
        pathOnHost: "/dev/ttyUSB0",
        pathInContainer: "/dev/ttyUSB0",
        cgroupPermissions: "rwm",
      },
    ]);
    expect(web.dependsOn).toEqual(["api"]);
  });

  it("maps named volumes to Edgehog volume ids and paths to binds", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    volumes:
      - app-data:/var/lib/app
      - /host/config:/etc/app:ro
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    const app = result.data.services[0];

    expect(app.container.volumes).toEqual([{ id: "volume-1", target: "/var/lib/app" }]);
    expect(app.container.binds).toEqual(["/host/config:/etc/app:ro"]);
  });

  it("collects warnings for unsupported keys and unknown references", () => {
    const yaml = `
version: "3.9"
volumes:
  unused-volume: {}
services:
  web:
    image: nginx
    build: ./web
    healthcheck:
      test: echo ok
    networks:
      - missing-network
    volumes:
      - unknown-volume:/data
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    const { warnings } = result;

    expect(warnings.some((w) => w.includes("'build'"))).toBe(true);
    expect(warnings.some((w) => w.includes("'healthcheck'"))).toBe(true);
    expect(warnings.some((w) => w.includes("top-level key 'version'"))).toBe(true);
    expect(
      warnings.some((w) => w.includes("'missing-network' does not match")),
    ).toBe(true);
    expect(
      warnings.some((w) => w.includes("'unknown-volume' does not match")),
    ).toBe(true);
  });

  it("supports long syntax for volumes and map form for environment", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    environment:
      KEY: value
    volumes:
      - type: volume
        source: app-data
        target: /data
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    const app = result.data.services[0];

    expect(app.container.volumes).toEqual([{ id: "volume-1", target: "/data" }]);
  });

  it("parses map-form networks ignoring configuration details", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    networks:
      backend-net:
        aliases:
          - api
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    expect(result.data.services[0].container.networks).toEqual([
      { id: "network-2" },
    ]);
    expect(
      result.warnings.some((w) => w.includes("configuration details")),
    ).toBe(true);
  });

  it("returns an error for invalid YAML", () => {
    const result = composeToFormData("services: [unclosed");

    expect(result.ok).toBe(false);
  });
});

describe("formDataToCompose", () => {
  it("serializes services back to a compose file", () => {
    const { text } = formDataToCompose({
      services: [
        {
          name: "api",
          dependsOn: ["db"],
          container: {
            name: "api",
            image: { reference: "myorg/api:2.0.0" },
            restartPolicy: "on_failure",
            portBindings: ["8000:8000"],
            env: [{ key: "NODE_ENV", value: "production" }],
            capAdd: ["CAP_SYS_TIME"],
          },
        },
        {
          name: "db",
          dependsOn: [],
          container: {
            name: "db",
            image: { reference: "postgres:16" },
          },
        },
      ],
    });

    const parsed = parse(text) as {
      services: Record<string, Record<string, unknown>>;
    };

    expect(Object.keys(parsed.services)).toEqual(["api", "db"]);

    const api = parsed.services.api;

    expect(api.image).toBe("myorg/api:2.0.0");
    expect(api.restart).toBe("on-failure");
    expect(api.ports).toEqual(["8000:8000"]);
    expect(api.environment).toEqual({ NODE_ENV: "production" });
    expect(api.cap_add).toEqual(["CAP_SYS_TIME"]);
    expect(api.depends_on).toEqual(["db"]);
  });

  it("warns about form-only settings that cannot be serialized", () => {
    const { warnings } = formDataToCompose({
      services: [
        {
          name: "app",
          dependsOn: [],
          container: {
            name: "app",
            image: { reference: "app", imageCredentialsId: "creds-1" },
            deviceRequests: [
              {
                driver: "",
                count: -1,
                deviceIds: [],
                capabilities: [],
                options: "{}",
              },
            ],
          },
        },
      ],
    });

    expect(warnings.some((w) => w.includes("image credentials"))).toBe(true);
    expect(warnings.some((w) => w.includes("device requests"))).toBe(true);
  });
});

describe("compose round trip", () => {
  it("is stable through compose -> data -> compose", () => {
    const yaml = `
services:
  web:
    image: nginx:1.27
    hostname: web.local
    restart: always
    ports:
      - "8080:80"
    environment:
      KEY: value
    networks:
      - frontend-net
    mem_limit: 268435456
    depends_on:
      - worker
  worker:
    image: myorg/worker:1.0
    privileged: true
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0:rwm
`;

    const parsed = composeToFormData(yaml, context);

    expect(parsed.ok).toBe(true);

    if (!parsed.ok) return;

    const { text } = formDataToCompose(parsed.data, context);
    const reparsed = composeToFormData(text, context);

    expect(reparsed.ok).toBe(true);

    if (!reparsed.ok) return;

    expect(reparsed.data).toEqual(parsed.data);
  });
});
