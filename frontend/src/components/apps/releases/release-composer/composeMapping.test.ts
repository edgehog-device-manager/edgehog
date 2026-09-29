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
    container_name: my-web
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
    expect(warnings.some((w) => w.includes("'container_name'"))).toBe(true);
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
    expect(result.data.services[0].extras?.keys).toHaveProperty(
      "container_name",
      "my-web",
    );
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

    // Unknown service keys are kept as extras with a warning so user
    // settings survive round trips instead of failing validation.
    expect(unknownServiceKey.ok).toBe(true);

    if (!unknownServiceKey.ok) return;

    expect(
      unknownServiceKey.warnings.some((w) => w.includes("'not_a_compose_key'")),
    ).toBe(true);
    expect(unknownServiceKey.data.services[0].extras?.keys).toHaveProperty(
      "not_a_compose_key",
      true,
    );
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
    container_name: my-web
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
    expect(doc.services.web.container_name).toBe("my-web");
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

describe("process and healthcheck mapping", () => {
  it("parses user, working_dir, command and entrypoint", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    user: "1000:1000"
    working_dir: /srv/app
    command: bundle exec rails s
    entrypoint:
      - /bin/sh
      - -c
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    const app = result.data.services[0];

    expect(app.container.user).toBe("1000:1000");
    expect(app.container.workingDirectory).toBe("/srv/app");
    expect(app.container.command).toBe("bundle exec rails s");
    expect(app.container.entrypoint).toBe("/bin/sh -c");
    expect(result.warnings).toEqual([]);
  });

  it("parses healthcheck with durations, retries and shell test", () => {
    const yaml = `
services:
  web:
    image: nginx:1.27
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 1m
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    const web = result.data.services[0];

    expect(web.container.healthcheckTest).toBe("curl -f http://localhost");
    expect(web.container.healthcheckInterval).toBe(30_000_000_000);
    expect(web.container.healthcheckTimeout).toBe(5_000_000_000);
    expect(web.container.healthcheckRetries).toBe(3);
    expect(web.container.healthcheckStartPeriod).toBe(60_000_000_000);
  });

  it("parses restart retry counts and warns on invalid arguments", () => {
    const counted = composeToFormData(`
services:
  worker:
    image: worker:1.0
    restart: "on-failure:5"
`);

    expect(counted.ok).toBe(true);

    if (!counted.ok) return;

    expect(counted.data.services[0].container.restartPolicy).toBe("on_failure");
    expect(
      counted.data.services[0].container.restartPolicyMaximumRetryCount,
    ).toBe(5);

    const invalid = composeToFormData(`
services:
  worker:
    image: worker:1.0
    restart: "always:5"
`);

    expect(invalid.ok).toBe(true);

    if (!invalid.ok) return;

    expect(invalid.warnings.some((w) => w.includes("restart argument"))).toBe(
      true,
    );
  });

  it("warns on healthcheck disable and invalid durations", () => {
    const result = composeToFormData(`
services:
  web:
    image: nginx
    healthcheck:
      test: ["NONE"]
      disable: true
      interval: soon
`);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    expect(result.data.services[0].container.healthcheckTest).toBe("NONE");
    expect(result.warnings.some((w) => w.includes("healthcheck disable"))).toBe(
      true,
    );
    expect(
      result.warnings.some((w) => w.includes("healthcheck duration")),
    ).toBe(true);
  });

  it("round-trips process and healthcheck fields stably", () => {
    const yaml = `
services:
  web:
    image: nginx:1.27
    user: www-data
    working_dir: /usr/share/nginx
    command: nginx -g 'daemon off;'
    restart: "on-failure:3"
    healthcheck:
      test:
        - CMD-SHELL
        - curl -f http://localhost
      interval: 30s
      timeout: 5s
      retries: 3
`;

    const parsed = composeToFormData(yaml, context);

    expect(parsed.ok).toBe(true);

    if (!parsed.ok) return;

    const { text, warnings } = formDataToCompose(parsed.data, context);

    expect(warnings).toEqual([]);

    const reparsed = composeToFormData(text, context);

    expect(reparsed.ok).toBe(true);

    if (!reparsed.ok) return;

    expect(reparsed.data).toEqual(parsed.data);

    const doc = parse(text) as TestDoc;

    expect(doc.services.web.restart).toBe("on-failure:3");
    expect(doc.services.web.healthcheck).toMatchObject({
      interval: "30s",
      timeout: "5s",
      retries: 3,
    });
  });
});

describe("blkio, logging and key/value mapping", () => {
  it("parses labels and sysctls in map and list form", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    labels:
      com.example.team: backend
      com.example.port: 8080
    sysctls:
      - net.core.somaxconn=1024
      - net.ipv4.ip_forward=1
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    const app = result.data.services[0];

    expect(app.container.labels).toEqual([
      { key: "com.example.team", value: "backend" },
      { key: "com.example.port", value: "8080" },
    ]);
    expect(app.container.sysctls).toEqual([
      { key: "net.core.somaxconn", value: "1024" },
      { key: "net.ipv4.ip_forward", value: "1" },
    ]);
  });

  it("parses ulimits in single-value and object form", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    ulimits:
      nofile: 1024
      nproc:
        soft: 100
        hard: 200
      bogus: not-a-number
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    expect(result.data.services[0].container.ulimits).toEqual([
      { name: "nofile", soft: 1024, hard: 1024 },
      { name: "nproc", soft: 100, hard: 200 },
    ]);
    expect(result.warnings.some((w) => w.includes("ulimit 'bogus'"))).toBe(
      true,
    );
  });

  it("parses logging driver and options", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    logging:
      driver: json-file
      options:
        max-size: 10m
        max-file: "3"
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    expect(result.data.services[0].container.logType).toBe("json-file");
    expect(result.data.services[0].container.logConfig).toEqual([
      { key: "max-size", value: "10m" },
      { key: "max-file", value: "3" },
    ]);
  });

  it("parses blkio_config with string numerics", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    blkio_config:
      weight: "500"
      weight_device:
        - path: /dev/sda
          weight: 400
      device_read_bps:
        - path: /dev/sda
          rate: 1048576
`;

    const result = composeToFormData(yaml, context);

    expect(result.ok).toBe(true);

    if (!result.ok) return;

    const app = result.data.services[0];

    expect(app.container.blkioWeight).toBe(500);
    expect(app.container.blkioWeightDevice).toEqual([
      { path: "/dev/sda", weight: 400 },
    ]);
    expect(app.container.blkioDeviceReadBps).toEqual([
      { path: "/dev/sda", rate: 1048576 },
    ]);
  });

  it("round-trips blkio, logging and key/value fields stably", () => {
    const yaml = `
services:
  app:
    image: app:1.0
    labels:
      com.example.team: backend
    sysctls:
      net.core.somaxconn: "1024"
    ulimits:
      nofile: 1024
      nproc:
        soft: 100
        hard: 200
    logging:
      driver: json-file
      options:
        max-size: 10m
    blkio_config:
      weight: 500
      device_read_bps:
        - path: /dev/sda
          rate: 1048576
`;

    const parsed = composeToFormData(yaml, context);

    expect(parsed.ok).toBe(true);

    if (!parsed.ok) return;

    const { text, warnings } = formDataToCompose(parsed.data, context);

    expect(warnings).toEqual([]);

    const reparsed = composeToFormData(text, context);

    expect(reparsed.ok).toBe(true);

    if (!reparsed.ok) return;

    expect(reparsed.data).toEqual(parsed.data);
  });
});
