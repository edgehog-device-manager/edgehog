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

import type { ContainerInputData } from "@/forms/validation";

export type ComposeServiceData = {
  name: string;
  dependsOn: string[];
  container: ContainerInputData;
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
  | { ok: true; data: ReleaseComposeData; warnings: string[] }
  | { ok: false; error: string };

/* ------------------------------ helpers ------------------------------ */

const asRecord = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};

const asStringArray = (value: unknown): string[] => {
  if (typeof value === "string") return [value];
  if (!Array.isArray(value)) return [];

  return value.flatMap((item) => (typeof item === "string" ? [item] : []));
};

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

const parseIntValue = (value: unknown): number | undefined => parseMemory(value);

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

  if (!policy) return { warning: `unsupported value '${value}'` };
  if (arg) return { policy, warning: `restart argument '${arg}' ignored` };

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
  context: string,
  warnings: string[],
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

  if (value && typeof value === "object") {
    return Object.entries(asRecord(value)).map(([key, val]) => ({
      key,
      value: val == null ? "" : String(val),
    }));
  }

  warnings.push(`${context}: unsupported environment format ignored`);

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

const deviceMappingFromEntry = (
  entry: string,
  context: string,
  warnings: string[],
): DeviceMappingData | null => {
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

  warnings.push(`${context}: unsupported device entry '${entry}' ignored`);

  return null;
};

const labelToId = (
  options: LabelOption[] | undefined,
  label: string,
): string | null => options?.find((option) => option.label === label)?.value ?? null;

const idToLabel = (
  options: LabelOption[] | undefined,
  id: string,
): string | null => options?.find((option) => option.value === id)?.label ?? null;

const SUPPORTED_SERVICE_KEYS = new Set([
  "image",
  "environment",
  "env_file",
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
]);

const SUPPORTED_TOP_LEVEL_KEYS = new Set(["services"]);

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
    return { ok: true, data: { services: [] }, warnings: [] };
  }

  const root = asRecord(document);
  const warnings: string[] = [];

  for (const key of Object.keys(root)) {
    if (!SUPPORTED_TOP_LEVEL_KEYS.has(key)) {
      warnings.push(`top-level key '${key}' is not supported and was ignored`);
    }
  }

  const servicesRoot = root.services;

  if (servicesRoot == null) {
    return { ok: true, data: { services: [] }, warnings };
  }

  const servicesRecord = asRecord(servicesRoot);
  const services: ComposeServiceData[] = [];

  for (const [name, rawService] of Object.entries(servicesRecord)) {
    const service = asRecord(rawService);
    const ctx = `service '${name}'`;

    for (const key of Object.keys(service)) {
      if (!SUPPORTED_SERVICE_KEYS.has(key)) {
        warnings.push(`${ctx}: key '${key}' is not supported and was ignored`);
      }
    }

    const container: ContainerInputData = {
      name,
      image: { reference: "" },
      hostname: typeof service.hostname === "string" ? service.hostname : undefined,
      networkMode:
        typeof service.network_mode === "string" ? service.network_mode : undefined,
      portBindings: asStringArray(service.ports),
      binds: [],
      volumes: [],
      extraHosts: asStringArray(service.extra_hosts),
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
      env: envToKeyValuePairs(service.environment, ctx, warnings),
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
      warnings.push(`${ctx}: unsupported image definition ignored`);
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
          warnings.push(`${ctx}: unsupported volume entry '${entry}' ignored`);

          continue;
        }

        if (isBindSource(parsed.source)) {
          container.binds?.push(entry);

          continue;
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
        warnings.push(`${ctxVolume}: unsupported volume type ignored`);

        continue;
      }

      if (type === "bind") {
        container.binds?.push(`${source}:${target}`);

        continue;
      }

      const volumeId = labelToId(context.volumeOptions, source);

      if (volumeId == null) {
        warnings.push(`${ctxVolume} does not match any Edgehog volume`);

        continue;
      }

      container.volumes?.push({ id: volumeId, target });
    }

    // networks
    const networkEntries = Array.isArray(service.networks)
      ? service.networks
      : typeof service.networks === "string"
        ? [service.networks]
        : [];

    for (const entry of networkEntries) {
      let label: unknown = entry;

      if (entry != null && typeof entry === "object") {
        const network = asRecord(entry);

        label = typeof network.name === "string" ? network.name : undefined;

        warnings.push(`${ctx}: network configuration details were ignored`);
      }

      if (typeof label !== "string") continue;

      const networkId = labelToId(context.networkOptions, label);

      if (networkId == null) {
        warnings.push(
          `${ctx}: network '${label}' does not match any Edgehog network`,
        );

        continue;
      }

      container.networks?.push({ id: networkId });
    }

    if (
      !Array.isArray(service.networks) &&
      service.networks != null &&
      typeof service.networks === "object"
    ) {
      for (const key of Object.keys(asRecord(service.networks))) {
        warnings.push(
          `${ctx}: network '${key}' configuration details were ignored`,
        );

        const networkId = labelToId(context.networkOptions, key);

        if (networkId == null) {
          warnings.push(
            `${ctx}: network '${key}' does not match any Edgehog network`,
          );

          continue;
        }

        container.networks?.push({ id: networkId });
      }
    }

    // devices
    for (const entry of asStringArray(service.devices)) {
      const mapping = deviceMappingFromEntry(entry, ctx, warnings);

      if (mapping) container.deviceMappings?.push(mapping);
    }

    // depends_on
    let dependsOn: string[] = [];

    if (
      Array.isArray(service.depends_on) ||
      typeof service.depends_on === "string"
    ) {
      dependsOn = asStringArray(service.depends_on);
    } else if (service.depends_on != null && typeof service.depends_on === "object") {
      for (const [key, rawCondition] of Object.entries(
        asRecord(service.depends_on),
      )) {
        if (asRecord(rawCondition).condition) {
          warnings.push(`${ctx}: depends_on condition for '${key}' ignored`);
        }
      }

      dependsOn = Object.keys(asRecord(service.depends_on));
    }

    services.push({ name, dependsOn, container });
  }

  return { ok: true, data: { services }, warnings };
};

/* ------------------------- form data -> YAML ------------------------- */

export type SerializeResult = {
  text: string;
  warnings: string[];
};

export const formDataToCompose = (
  data: ReleaseComposeData,
  context: MappingContext = {},
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

    if (container.networks?.length) {
      const labels: string[] = [];

      for (const network of container.networks) {
        const label = idToLabel(context.networkOptions, network.id);

        if (label == null) {
          warnings.push(`${ctx}: unlinked network could not be serialized`);

          continue;
        }

        labels.push(label);
      }

      if (labels.length) output.networks = labels;
    }

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

          return [
            entry.slice(0, separator),
            entry.slice(separator + 1),
          ];
        }),
      );
    }

    if (container.volumeDriver) output.volume_driver = container.volumeDriver;

    if (container.memory != null) output.mem_limit = container.memory;
    if (container.memoryReservation != null)
      output.mem_reservation = container.memoryReservation;
    if (container.memorySwap != null) output.memswap_limit = container.memorySwap;
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
      warnings.push(
        `${ctx}: device requests are configured from the form only and are not part of the compose file`,
      );
    }

    if (container.image?.imageCredentialsId) {
      warnings.push(
        `${ctx}: image credentials are configured from the form only and are not part of the compose file`,
      );
    }

    if (service.dependsOn.length) {
      output.depends_on = [...service.dependsOn];
    }

    services[service.name] = output;
  }

  return {
    text: stringify({ services }, { sortMapEntries: false }),
    warnings,
  };
};
