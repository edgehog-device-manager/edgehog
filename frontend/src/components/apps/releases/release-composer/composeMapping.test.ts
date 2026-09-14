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

type TestServiceDoc = Record<string, unknown>;

type TestDoc = {
  services: Record<string, TestServiceDoc>;
} & Record<string, unknown>;

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

    expect(app.container.volumes).toEqual([
      { id: "volume-1", target: "/var/lib/app" },
    ]);
    expect(app.container.binds).toEqual(["/host/config:/etc/app:ro"]);
  });

  it("warns about unsupported keys but keeps them as extras", () => {
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
    expect(warnings.some((w) => w.includes("not supported by Edgehog"))).toBe(
      true,
    );
    expect(warnings.some((w) => w.includes("'healthcheck'"))).toBe(true);
    expect(warnings.some((w) => w.includes("top-level key 'version'"))).toBe(
      true,
    );
    expect(warnings.some((w) => w.includes("top-level key 'volumes'"))).toBe(
      true,
    );
    expect(
      warnings.some((w) => w.includes("'missing-network' does not match")),
    ).toBe(true);
    expect(
      warnings.some((w) => w.includes("'unknown-volume' does not match")),
    ).toBe(true);

    expect(result.topLevelExtras).toEqual({
      version: "3.9",
      volumes: { "unused-volume": {} },
    });
    expect(result.data.services[0].extras?.keys).toMatchObject({
      build: "./web",
    });
    expect(result.data.services[0].extras?.keys).toHaveProperty("healthcheck");
  });

  it("rejects documents violating the Compose Specification", () => {
    const wrongImageType = composeToFormData(`
services:
  web:
    image: 123
`);

    expect(wrongImageType.ok).toBe(false);

    const unknownTopLevelKey = composeToFormData(`
services: {}
services:
  web:
    image: nginx
`);

    expect(unknownTopLevelKey.ok).toBe(false);

    const unknownServiceKey = composeToFormData(`
services:
  web:
    image: nginx
    not_a_compose_key: true
`);

    expect(unknownServiceKey.ok).toBe(false);
  });

  it("keeps x- extensions as warnings without failing validation", () => {
    const yaml = `
x-common: &common
  restart: always
services:
  web:
    image: nginx
    x-custom: hello
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    expect(result.topLevelExtras["x-common"]).toEqual({ restart: "always" });
    expect(result.data.services[0].extras?.keys["x-custom"]).toBe("hello");

    const serialized = formDataToCompose(result.data, context, {
      topLevelExtras: result.topLevelExtras,
    });

    const doc = parse(serialized.text) as TestDoc;

    expect(doc["x-common"]).toEqual({ restart: "always" });
    expect(doc.services.web["x-custom"]).toBe("hello");
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

    expect(app.container.volumes).toEqual([
      { id: "volume-1", target: "/data" },
    ]);
  });

  it("converts long-syntax ports and warns about unsupported port options", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    ports:
      - target: 80
        published: "8080"
        protocol: udp
        mode: host
      - 9999
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    expect(result.data.services[0].container.portBindings).toEqual([
      "8080:80/udp",
      "9999",
    ]);
    expect(result.warnings.some((w) => w.includes("mode"))).toBe(true);
  });

  it("converts map-form extra_hosts", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    extra_hosts:
      db-host: "192.168.1.10"
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    expect(result.data.services[0].container.extraHosts).toEqual([
      "db-host:192.168.1.10",
    ]);
  });

  it("warns that env_file entries cannot be resolved", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    env_file:
      - .env
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    expect(result.warnings.some((w) => w.includes("env_file"))).toBe(true);
    expect(result.data.services[0].extras?.keys.env_file).toEqual([".env"]);
  });

  it("extracts depends_on names and keeps conditions as extras", () => {
    const yaml = `
services:
  web:
    image: nginx
    depends_on:
      api:
        condition: service_healthy
      worker:
        condition: service_started
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    const web = result.data.services[0];

    expect(web.dependsOn).toEqual(["api", "worker"]);
    expect(
      result.warnings.some((w) => w.includes("depends_on conditions")),
    ).toBe(true);
    expect(web.extras?.dependsOnRaw).toEqual({
      api: { condition: "service_healthy" },
      worker: { condition: "service_started" },
    });
    expect(web.extras?.dependsOnExtracted).toEqual(["api", "worker"]);
  });

  it("parses map-form networks keeping configuration as extras", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    networks:
      backend-net:
        aliases:
          - api
      mystery-net: {}
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
    expect(
      result.warnings.some((w) => w.includes("'mystery-net' does not match")),
    ).toBe(true);
    expect(result.data.services[0].extras?.networksRaw).toEqual({
      "backend-net": { aliases: ["api"] },
      "mystery-net": {},
    });
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

  it("restores unsupported fields when serializing", () => {
    const yaml = `
version: "3.9"
services:
  web:
    image: nginx
    build: ./web
    healthcheck:
      test: echo ok
`;

    const parsed = composeToFormData(yaml, context);

    expect(parsed.ok).toBe(true);

    if (!parsed.ok) return;

    // simulate a form edit on a supported field
    parsed.data.services[0].container.image!.reference = "nginx:1.27";

    const { text } = formDataToCompose(parsed.data, context, {
      topLevelExtras: parsed.topLevelExtras,
    });

    const doc = parse(text) as TestDoc;

    expect(doc.version).toBe("3.9");
    expect(doc.services.web.build).toBe("./web");
    expect(doc.services.web.healthcheck).toEqual({ test: "echo ok" });
    expect(doc.services.web.image).toBe("nginx:1.27");
  });

  it("restores depends_on conditions when unchanged and drops them when edited", () => {
    const yaml = `
services:
  web:
    image: nginx
    depends_on:
      api:
        condition: service_healthy
`;

    const parsed = composeToFormData(yaml, context);

    expect(parsed.ok).toBe(true);

    if (!parsed.ok) return;

    const untouched = parse(formDataToCompose(parsed.data).text) as TestDoc;

    expect(untouched.services.web.depends_on).toEqual({
      api: { condition: "service_healthy" },
    });

    parsed.data.services[0].dependsOn = ["worker"];

    const edited = parse(formDataToCompose(parsed.data).text) as TestDoc;

    expect(edited.services.web.depends_on).toEqual(["worker"]);
  });

  it("restores network configuration details when unchanged and canonicalizes when edited", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    networks:
      backend-net:
        aliases:
          - api
`;

    const parsed = composeToFormData(yaml, context);

    expect(parsed.ok).toBe(true);

    if (!parsed.ok) return;

    const untouched = parse(
      formDataToCompose(parsed.data, context).text,
    ) as TestDoc;

    expect(untouched.services.app.networks).toEqual({
      "backend-net": { aliases: ["api"] },
    });

    parsed.data.services[0].container.networks = [];

    const edited = parse(
      formDataToCompose(parsed.data, context).text,
    ) as TestDoc;

    expect(edited.services.app.networks).toBeUndefined();
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

  it("is stable with unsupported fields through repeated round trips", () => {
    const yaml = `
version: "3.8"
services:
  web:
    image: nginx
    build:
      context: ./web
    depends_on:
      api:
        condition: service_started
`;

    const first = composeToFormData(yaml, context);

    expect(first.ok).toBe(true);

    if (!first.ok) return;

    const secondPass = formDataToCompose(first.data, context, {
      topLevelExtras: first.topLevelExtras,
    });
    const second = composeToFormData(secondPass.text, context);

    expect(second.ok).toBe(true);

    if (!second.ok) return;

    expect(second.data).toEqual(first.data);
    expect(second.topLevelExtras).toEqual(first.topLevelExtras);
  });
});
