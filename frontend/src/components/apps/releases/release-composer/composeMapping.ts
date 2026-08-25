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

import { parse, stringify } from "yaml";
import type { ZodError } from "zod";

import { composeSpecSchema } from "./composeSpecSchema.generated";
import type { ContainerInputData } from "@/forms/validation";

export type ComposeServiceExtras = {
  /** Service keys that are not supported by Edgehog, preserved verbatim. */
  keys: Record<string, unknown>;
  /** Original map-form depends_on, restored when the extracted names did not change. */
  dependsOnRaw?: Record<string, unknown>;
  /** Service names extracted from dependsOnRaw. */
  dependsOnExtracted?: string[];
  /** Original map-form networks, restored when the matched networks did not change. */
  networksRaw?: Record<string, unknown>;
  /** Network labels that matched an Edgehog network at parse time. */
  networksMatchedLabels?: string[];
};

export type ComposeServiceData = {
  name: string;
  dependsOn: string[];
  container: ContainerInputData;
  extras?: ComposeServiceExtras;
};

export type ReleaseComposeData = {
  services: ComposeServiceData[];
};

type LabelOption = {
  label: string;
  value: string;
};

type DeviceMappingData = {
  pathOnHost: string;
  pathInContainer: string;
  cgroupPermissions: string;
};

export type MappingContext = {
  networkOptions?: LabelOption[];
  volumeOptions?: LabelOption[];
};

export type ComposeMappingResult =
  | {
      ok: true;
      data: ReleaseComposeData;
      topLevelExtras: Record<string, unknown>;
      warnings: string[];
    }
  | { ok: false; error: string };

/* ------------------------------ helpers ------------------------------ */

const clone = <T>(value: T): T =>
  typeof structuredClone === "function"
    ? structuredClone(value)
    : (JSON.parse(JSON.stringify(value)) as T);

const asRecord = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};

const asStringArray = (value: unknown): string[] => {
  if (typeof value === "string") return [value];
  if (!Array.isArray(value)) return [];

  return value.flatMap((item) => (typeof item === "string" ? [item] : []));
};

const sameStrings = (a: string[], b: string[]) =>
  a.length === b.length && a.every((item, index) => item === b[index]);

const parseMemory = (value: unknown): number | undefined => {
  if (typeof value === "number") return value;
  if (typeof value !== "string") return undefined;

  const match = value.trim().match(/^(\d+(?:\.\d+)?)\s*([bkmg]?)b?$/i);
  if (!match) return undefined;

  const amount = parseFloat(match[1]);
  const unit = match[2].toLowerCase();

  const multipliers: Record<string, number> = {
    "": 1,
    b: 1,
    k: 1024,
    m: 1024 ** 2,
    g: 1024 ** 3,
  };

  return Math.round(amount * multipliers[unit]);
};

const parseIntValue = (value: unknown): number | undefined =>
  parseMemory(value);

const restartPolicyToEdgehog = (
  value: unknown,
): { policy?: string; warning?: string } => {
  if (typeof value !== "string") return { warning: `unsupported value` };

  const [rawPolicy, arg] = value.split(":");

  const mapping: Record<string, string> = {
    no: "no",
    always: "always",
    "on-failure": "on_failure",
    unless_stopped: "unless_stopped",
    "unless-stopped": "unless_stopped",
  };

  const policy = mapping[rawPolicy.trim().toLowerCase()];

  if (!policy)
    return { policy: undefined, warning: `unsupported value '${value}'` };
  if (arg)
    return {
      policy,
      warning: `restart argument '${arg}' is not supported and will be ignored`,
    };

  return { policy };
};

const restartPolicyToCompose = (policy?: string): string | undefined => {
  if (!policy) return undefined;

  const mapping: Record<string, string> = {
    no: "no",
    always: "always",
    on_failure: "on-failure",
    unless_stopped: "unless-stopped",
  };

  return mapping[policy];
};

const envToKeyValuePairs = (
  value: unknown,
): { key: string; value: string }[] => {
  if (!value) return [];

  if (Array.isArray(value)) {
    return value.flatMap((entry) => {
      if (typeof entry !== "string") return [];

      const separator = entry.indexOf("=");

      if (separator === -1) {
        return [{ key: entry, value: "" }];
      }

      return [
        {
          key: entry.slice(0, separator),
          value: entry.slice(separator + 1),
        },
      ];
    });
  }

  if (typeof value === "object") {
    return Object.entries(asRecord(value)).map(([key, val]) => ({
      key,
      value: val == null ? "" : String(val),
    }));
  }

  return [];
};

const splitVolumeShortSyntax = (
  entry: string,
): { source: string; target: string; mode?: string } | null => {
  const parts = entry.split(":").map((part) => part.trim());

  if (parts.length === 2 && parts.every((part) => part !== "")) {
    return { source: parts[0], target: parts[1] };
  }

  if (parts.length === 3 && parts.every((part) => part !== "")) {
    return { source: parts[0], target: parts[1], mode: parts[2] };
  }

  return null;
};

const isBindSource = (source: string) =>
  source.startsWith("/") ||
  source.startsWith(".") ||
  source.startsWith("~") ||
  /^[A-Za-z]:[\\/]/.test(source);

const deviceMappingFromEntry = (entry: string): DeviceMappingData | null => {
  const parts = entry.split(":").map((part) => part.trim());

  if (parts.length === 2 && parts.every((part) => part !== "")) {
    return {
      pathOnHost: parts[0],
      pathInContainer: parts[1],
      cgroupPermissions: "rwm",
    };
  }

  if (parts.length === 3 && parts.every((part) => part !== "")) {
    return {
      pathOnHost: parts[0],
      pathInContainer: parts[1],
      cgroupPermissions: parts[2],
    };
  }

  return null;
};

const portBindingFromEntry = (
  entry: unknown,
  context: string,
  warnings: string[],
): string | null => {
  if (typeof entry === "string") {
    return entry === "" ? null : entry;
  }

  if (typeof entry === "number") {
    return String(entry);
  }

  const port = asRecord(entry);
  const target = port.target != null ? String(port.target) : "";
  const published = port.published != null ? String(port.published) : "";
  const protocol = typeof port.protocol === "string" ? port.protocol : "";

  if (target === "") {
    warnings.push(
      `${context}: port without a target is not supported and will be ignored`,
    );

    return null;
  }

  const unsupportedOptions = ["mode", "name", "app_protocol"].filter(
    (key) => port[key] != null,
  );

  if (unsupportedOptions.length > 0) {
    warnings.push(
      `${context}: port option(s) ${unsupportedOptions.join(", ")} are not supported and will be ignored`,
    );
  }

  const targetWithProtocol =
    protocol && protocol !== "tcp" ? `${target}/${protocol}` : target;

  if (port.host_ip != null && published !== "") {
    return `${String(port.host_ip)}:${published}:${targetWithProtocol}`;
  }

  if (published !== "") {
    return `${published}:${targetWithProtocol}`;
  }

  return targetWithProtocol;
};

const extraHostsFromValue = (value: unknown): string[] => {
  if (Array.isArray(value)) {
    return value.flatMap((entry) => (typeof entry === "string" ? [entry] : []));
  }

  return Object.entries(asRecord(value)).flatMap(([host, address]) => {
    if (typeof address === "string") {
      return [`${host}:${address}`];
    }

    if (Array.isArray(address)) {
      return address.flatMap((ip) =>
        typeof ip === "string" ? [`${host}:${ip}`] : [],
      );
    }

    return [];
  });
};

const labelToId = (
  options: LabelOption[] | undefined,
  label: string,
): string | null =>
  options?.find((option) => option.label === label)?.value ?? null;

const idToLabel = (
  options: LabelOption[] | undefined,
  id: string,
): string | null =>
  options?.find((option) => option.value === id)?.label ?? null;

/**
 * Service keys that Edgehog can represent in its containers. Anything else is
 * kept in the compose file and reported as a warning.
 */
const SUPPORTED_SERVICE_KEYS = new Set([
  "image",
  "environment",
  "ports",
  "networks",
  "network_mode",
  "extra_hosts",
  "hostname",
  "volumes",
  "tmpfs",
  "read_only",
  "storage_opt",
  "volume_driver",
  "restart",
  "privileged",
  "cap_add",
  "cap_drop",
  "mem_limit",
  "mem_reservation",
  "memswap_limit",
  "mem_swappiness",
  "cpu_period",
  "cpu_quota",
  "cpu_rt_period",
  "cpu_rt_runtime",
  "devices",
  "depends_on",
  "deploy",
]);

const formatSchemaIssues = (error: ZodError): string => {
  const parts = error.issues.slice(0, 5).map((issue) => {
    const location = issue.path.length > 0 ? issue.path.join(".") : "document";

    return `${location}: ${issue.message}`;
  });

  if (error.issues.length > 5) {
    parts.push(`…and ${error.issues.length - 5} more`);
  }

  return parts.join("; ");
};

/* ------------------------- YAML -> form data ------------------------- */

export const composeToFormData = (
  yamlText: string,
  context: MappingContext = {},
): ComposeMappingResult => {
  let document: unknown;

  try {
    document = parse(yamlText);
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }

  if (document == null) {
    return {
      ok: true,
      data: { services: [] },
      topLevelExtras: {},
      warnings: [],
    };
  }

  const validated = composeSpecSchema.safeParse(document);

  if (!validated.success) {
    return { ok: false, error: formatSchemaIssues(validated.error) };
  }

  const root = asRecord(document);
  const warnings: string[] = [];
  const topLevelExtras: Record<string, unknown> = {};

  for (const key of Object.keys(root)) {
    if (key !== "services") {
      topLevelExtras[key] = clone(root[key]);
      warnings.push(
        `top-level key '${key}' is not supported by Edgehog and will be ignored`,
      );
    }
  }

  const servicesRecord = asRecord(root.services);
  const services: ComposeServiceData[] = [];

  for (const [name, rawService] of Object.entries(servicesRecord)) {
    const service = asRecord(rawService);
    const ctx = `service '${name}'`;
    const extras: ComposeServiceExtras = { keys: {} };

    for (const key of Object.keys(service)) {
      if (!SUPPORTED_SERVICE_KEYS.has(key)) {
        extras.keys[key] = clone(service[key]);

        warnings.push(
          key === "env_file"
            ? `${ctx}: env_file entries cannot be resolved by Edgehog and will be ignored`
            : `${ctx}: key '${key}' is not supported by Edgehog and will be ignored`,
        );
      }
    }

    const container: ContainerInputData = {
      name,
      image: { reference: "" },
      hostname:
        typeof service.hostname === "string" ? service.hostname : undefined,
      networkMode:
        typeof service.network_mode === "string"
          ? service.network_mode
          : undefined,
      portBindings: [],
      binds: [],
      volumes: [],
      extraHosts: extraHostsFromValue(service.extra_hosts),
      tmpfs: asStringArray(service.tmpfs),
      readOnlyRootfs: service.read_only === true,
      privileged: service.privileged === true,
      capAdd: asStringArray(service.cap_add) as ContainerInputData["capAdd"],
      capDrop: asStringArray(service.cap_drop) as ContainerInputData["capDrop"],
      volumeDriver:
        typeof service.volume_driver === "string"
          ? service.volume_driver
          : undefined,
      storageOpt: Object.entries(asRecord(service.storage_opt)).map(
        ([key, value]) => `${key}=${String(value)}`,
      ),
      env: envToKeyValuePairs(service.environment),
      restartPolicy: undefined,
      networks: [],
      deviceMappings: [],
      deviceRequests: [],
    };

    // image
    if (typeof service.image === "string") {
      container.image = { reference: service.image };
    } else if (service.image == null) {
      warnings.push(`${ctx}: 'image' is missing`);
    } else {
      warnings.push(
        `${ctx}: unsupported image definition is not supported and will be ignored`,
      );
    }

    // restart policy
    if (service.restart != null) {
      const { policy, warning } = restartPolicyToEdgehog(service.restart);

      container.restartPolicy = policy;

      if (warning) warnings.push(`${ctx}: restart ${warning}`);
    }

    // resource limits
    container.memory = parseIntValue(service.mem_limit);
    container.memoryReservation = parseIntValue(service.mem_reservation);
    container.memorySwap = parseIntValue(service.memswap_limit);
    container.memorySwappiness = parseIntValue(service.mem_swappiness);
    container.cpuPeriod = parseIntValue(service.cpu_period);
    container.cpuQuota = parseIntValue(service.cpu_quota);
    container.cpuRealtimePeriod = parseIntValue(service.cpu_rt_period);
    container.cpuRealtimeRuntime = parseIntValue(service.cpu_rt_runtime);

    // ports
    if (Array.isArray(service.ports)) {
      for (const entry of service.ports) {
        const binding = portBindingFromEntry(entry, ctx, warnings);

        if (binding) container.portBindings?.push(binding);
      }
    }

    // volumes and binds
    const volumeEntries = Array.isArray(service.volumes)
      ? service.volumes
      : typeof service.volumes === "string"
        ? [service.volumes]
        : [];

    for (const entry of volumeEntries) {
      if (entry == null) continue;

      if (typeof entry === "string") {
        const parsed = splitVolumeShortSyntax(entry);

        if (!parsed) {
          warnings.push(
            `${ctx}: unsupported volume entry '${entry}' is not supported and will be ignored`,
          );

          continue;
        }

        if (isBindSource(parsed.source)) {
          container.binds?.push(entry);

          continue;
        }

        if (parsed.mode) {
          warnings.push(
            `${ctx}: volume option '${parsed.mode}' is not supported and will be ignored`,
          );
        }

        const volumeId = labelToId(context.volumeOptions, parsed.source);

        if (volumeId == null) {
          warnings.push(
            `${ctx}: volume '${parsed.source}' does not match any Edgehog volume`,
          );

          continue;
        }

        container.volumes?.push({ id: volumeId, target: parsed.target });

        continue;
      }

      const volume = asRecord(entry);
      const type = typeof volume.type === "string" ? volume.type : "volume";
      const target = typeof volume.target === "string" ? volume.target : "";
      const source = typeof volume.source === "string" ? volume.source : "";
      const ctxVolume = `${ctx} volume '${source || target}'`;

      if (type !== "bind" && type !== "volume") {
        warnings.push(
          `${ctxVolume}: volume type '${type}' is not supported and will be ignored`,
        );

        continue;
      }

      if (type === "bind") {
        const unsupportedVolumeOptions = Object.keys(volume).filter(
          (key) => !["type", "source", "target"].includes(key),
        );

        if (unsupportedVolumeOptions.length > 0) {
          warnings.push(
            `${ctxVolume}: bind option(s) ${unsupportedVolumeOptions.join(", ")} are not supported and will be ignored`,
          );
        }

        container.binds?.push(`${source}:${target}`);

        continue;
      }

      const unsupportedVolumeOptions = Object.keys(volume).filter(
        (key) => !["type", "source", "target"].includes(key),
      );

      if (unsupportedVolumeOptions.length > 0) {
        warnings.push(
          `${ctxVolume}: volume option(s) ${unsupportedVolumeOptions.join(", ")} are not supported and will be ignored`,
        );
      }

      const volumeId = labelToId(context.volumeOptions, source);

      if (volumeId == null) {
        warnings.push(`${ctxVolume} does not match any Edgehog volume`);

        continue;
      }

      container.volumes?.push({ id: volumeId, target });
    }

    // networks
    const matchedNetworkLabels: string[] = [];

    if (Array.isArray(service.networks)) {
      for (const label of service.networks) {
        if (typeof label !== "string") continue;

        const networkId = labelToId(context.networkOptions, label);

        if (networkId == null) {
          warnings.push(
            `${ctx}: network '${label}' does not match any Edgehog network`,
          );

          continue;
        }

        matchedNetworkLabels.push(label);
        container.networks?.push({ id: networkId });
      }
    } else if (
      service.networks != null &&
      typeof service.networks === "object"
    ) {
      extras.networksRaw = clone(service.networks) as Record<string, unknown>;

      for (const key of Object.keys(asRecord(service.networks))) {
        if (Object.keys(asRecord(asRecord(service.networks)[key])).length > 0) {
          warnings.push(
            `${ctx}: configuration details of network '${key}' are not supported and will be ignored`,
          );
        }

        const networkId = labelToId(context.networkOptions, key);

        if (networkId == null) {
          warnings.push(
            `${ctx}: network '${key}' does not match any Edgehog network`,
          );

          continue;
        }

        matchedNetworkLabels.push(key);
        container.networks?.push({ id: networkId });
      }

      extras.networksMatchedLabels = [...matchedNetworkLabels];
    }

    // devices
    if (Array.isArray(service.devices)) {
      for (const entry of service.devices) {
        if (typeof entry === "string") {
          const mapping = deviceMappingFromEntry(entry);

          if (mapping) {
            container.deviceMappings?.push(mapping);
          } else {
            warnings.push(
              `${ctx}: unsupported device entry '${entry}' is not supported and will be ignored`,
            );
          }

          continue;
        }

        const device = asRecord(entry);
        const source = typeof device.source === "string" ? device.source : "";
        const target =
          typeof device.target === "string" ? device.target : source;
        const permissions =
          typeof device.permissions === "string" ? device.permissions : "rwm";

        if (source === "") {
          warnings.push(
            `${ctx}: device entry without a source is not supported and will be ignored`,
          );

          continue;
        }

        container.deviceMappings?.push({
          pathOnHost: source,
          pathInContainer: target,
          cgroupPermissions: permissions,
        });
      }
    }
    // deploy (device requests only; other deploy keys are not supported)
    if (service.deploy != null && typeof service.deploy === "object") {
      const deploy = asRecord(service.deploy);
      const unsupportedDeployOptions = Object.keys(deploy).filter(
        (key) => key !== "resources",
      );

      if (unsupportedDeployOptions.length > 0) {
        warnings.push(
          `${ctx}: deploy option(s) ${unsupportedDeployOptions.join(", ")} are not supported and will be ignored`,
        );
      }

      const resources = asRecord(deploy.resources);
      const unsupportedResourceOptions = Object.keys(resources).filter(
        (key) => key !== "reservations",
      );

      if (unsupportedResourceOptions.length > 0) {
        warnings.push(
          `${ctx}: deploy.resources option(s) ${unsupportedResourceOptions.join(", ")} are not supported and will be ignored`,
        );
      }

      const reservations = asRecord(resources.reservations);
      const unsupportedReservationOptions = Object.keys(reservations).filter(
        (key) => key !== "devices",
      );

      if (unsupportedReservationOptions.length > 0) {
        warnings.push(
          `${ctx}: deploy.resources.reservations option(s) ${unsupportedReservationOptions.join(", ")} are not supported and will be ignored`,
        );
      }
      if (Array.isArray(reservations.devices)) {
        for (const entry of reservations.devices) {
          const device = asRecord(entry);
          const unsupportedDeviceOptions = Object.keys(device).filter(
            (key) =>
              !["driver", "count", "device_ids", "capabilities"].includes(key),
          );

          if (unsupportedDeviceOptions.length > 0) {
            warnings.push(
              `${ctx}: deploy device request option(s) ${unsupportedDeviceOptions.join(", ")} are not supported and will be ignored`,
            );
          }
          container.deviceRequests?.push({
            driver:
              typeof device.driver === "string" ? device.driver : undefined,
            count: typeof device.count === "number" ? device.count : undefined,
            deviceIds: asStringArray(device.device_ids),
            capabilities: Array.isArray(device.capabilities)
              ? device.capabilities.flatMap((capability) =>
                  Array.isArray(capability) ? asStringArray(capability) : [],
                )
              : [],
          });
        }
      }
    }

    // depends_on
    let dependsOn: string[] = [];

    if (
      Array.isArray(service.depends_on) ||
      typeof service.depends_on === "string"
    ) {
      dependsOn = asStringArray(service.depends_on);
    } else if (
      service.depends_on != null &&
      typeof service.depends_on === "object"
    ) {
      extras.dependsOnRaw = clone(service.depends_on) as Record<
        string,
        unknown
      >;

      dependsOn = Object.keys(asRecord(service.depends_on));
      extras.dependsOnExtracted = [...dependsOn];

      if (
        Object.values(asRecord(service.depends_on)).some(
          (condition) => Object.keys(asRecord(condition)).length > 0,
        )
      ) {
        warnings.push(
          `${ctx}: depends_on conditions are not supported and will be ignored`,
        );
      }
    }

    services.push({
      name,
      dependsOn,
      container,
      extras:
        Object.keys(extras.keys).length > 0 ||
        extras.dependsOnRaw != null ||
        extras.networksRaw != null
          ? extras
          : undefined,
    });
  }

  return { ok: true, data: { services }, topLevelExtras, warnings };
};

/* ------------------------- form data -> YAML ------------------------- */

export type SerializeResult = {
  text: string;
  warnings: string[];
};

export type SerializeOptions = {
  /** Unsupported top-level keys preserved from the original document. */
  topLevelExtras?: Record<string, unknown>;
};

export const formDataToCompose = (
  data: ReleaseComposeData,
  context: MappingContext = {},
  options: SerializeOptions = {},
): SerializeResult => {
  const warnings: string[] = [];
  const services: Record<string, Record<string, unknown>> = {};

  for (const service of data.services) {
    const container = service.container;
    const output: Record<string, unknown> = {};
    const ctx = `service '${service.name}'`;

    const imageReference = container.image?.reference;

    if (imageReference) {
      output.image = imageReference;
    }

    if (container.hostname) output.hostname = container.hostname;
    if (container.networkMode) output.network_mode = container.networkMode;

    const restart = restartPolicyToCompose(container.restartPolicy);

    if (restart) output.restart = restart;

    if (container.privileged) output.privileged = true;
    if (container.readOnlyRootfs) output.read_only = true;

    if (container.portBindings?.length) {
      output.ports = [...container.portBindings];
    }

    if (container.extraHosts?.length) {
      output.extra_hosts = [...container.extraHosts];
    }

    const networkLabels: string[] = [];

    for (const network of container.networks ?? []) {
      const label = idToLabel(context.networkOptions, network.id);

      if (label == null) {
        warnings.push(`${ctx}: unlinked network could not be serialized`);

        continue;
      }

      networkLabels.push(label);
    }

    if (networkLabels.length) output.networks = networkLabels;

    const volumeEntries: string[] = [];
    const bindEntries: string[] = [];

    for (const volume of container.volumes ?? []) {
      const label = idToLabel(context.volumeOptions, volume.id);

      if (label == null) {
        warnings.push(`${ctx}: unlinked volume could not be serialized`);

        continue;
      }

      volumeEntries.push(`${label}:${volume.target}`);
    }

    bindEntries.push(...(container.binds ?? []));

    if (volumeEntries.length || bindEntries.length) {
      output.volumes = [...bindEntries, ...volumeEntries];
    }

    if (container.tmpfs?.length) output.tmpfs = [...container.tmpfs];

    if (container.storageOpt?.length) {
      output.storage_opt = Object.fromEntries(
        container.storageOpt.map((entry) => {
          const separator = entry.indexOf("=");

          return [entry.slice(0, separator), entry.slice(separator + 1)];
        }),
      );
    }

    if (container.volumeDriver) output.volume_driver = container.volumeDriver;

    if (container.memory != null) output.mem_limit = container.memory;
    if (container.memoryReservation != null)
      output.mem_reservation = container.memoryReservation;
    if (container.memorySwap != null)
      output.memswap_limit = container.memorySwap;
    if (container.memorySwappiness != null)
      output.mem_swappiness = container.memorySwappiness;
    if (container.cpuPeriod != null) output.cpu_period = container.cpuPeriod;
    if (container.cpuQuota != null) output.cpu_quota = container.cpuQuota;
    if (container.cpuRealtimePeriod != null)
      output.cpu_rt_period = container.cpuRealtimePeriod;
    if (container.cpuRealtimeRuntime != null)
      output.cpu_rt_runtime = container.cpuRealtimeRuntime;

    if (container.capAdd?.length) output.cap_add = [...container.capAdd];
    if (container.capDrop?.length) output.cap_drop = [...container.capDrop];

    const env: unknown = container.env;

    if (Array.isArray(env) && env.length) {
      output.environment = Object.fromEntries(
        env.map((entry) => [entry.key, entry.value]),
      );
    } else if (typeof env === "string" && env.trim() && env.trim() !== "{}") {
      try {
        const parsed = JSON.parse(env);

        if (parsed && typeof parsed === "object") {
          output.environment = parsed;
        }
      } catch {
        warnings.push(`${ctx}: environment is not valid JSON and was skipped`);
      }
    }

    if (container.deviceMappings?.length) {
      output.devices = container.deviceMappings.map(
        ({ pathOnHost, pathInContainer, cgroupPermissions }) =>
          `${pathOnHost}:${pathInContainer}:${cgroupPermissions}`,
      );
    }

    if (container.deviceRequests?.length) {
      output.deploy = {
        resources: {
          reservations: {
            devices: container.deviceRequests.map((request) => {
              const device: Record<string, unknown> = {};

              if (request.driver) device.driver = request.driver;
              if (request.count != null) device.count = request.count;
              if (request.deviceIds?.length) {
                device.device_ids = [...request.deviceIds];
              }
              if (request.capabilities?.length) {
                device.capabilities = [[...request.capabilities]];
              }

              return device;
            }),
          },
        },
      };
    }

    if (container.image?.imageCredentialsId) {
      warnings.push(
        `${ctx}: image credentials are configured from the form only and are not part of the compose file`,
      );
    }

    if (container.deviceRequests?.length) {
      warnings.push(
        `${ctx}: device requests are configured from the form only and are not part of the compose file`,
      );
    }

    if (service.dependsOn.length) {
      output.depends_on = [...service.dependsOn];
    }

    // restore preserved fields; untouched partially-supported keys win over
    // their canonical serialization
    const extras = service.extras;

    if (extras) {
      if (
        extras.dependsOnRaw &&
        extras.dependsOnExtracted &&
        sameStrings(service.dependsOn, extras.dependsOnExtracted)
      ) {
        output.depends_on = clone(extras.dependsOnRaw);
      }

      if (
        extras.networksRaw &&
        extras.networksMatchedLabels &&
        sameStrings(networkLabels, extras.networksMatchedLabels)
      ) {
        output.networks = clone(extras.networksRaw);
      }

      Object.assign(output, clone(extras.keys));
    }

    services[service.name] = output;
  }

  return {
    text: stringify(
      { ...clone(options.topLevelExtras), services },
      { sortMapEntries: false },
    ),
    warnings,
  };
};
