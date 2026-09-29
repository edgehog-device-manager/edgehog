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

import { parse } from "yaml";

import { composeSpecSchema } from "./composeSpecSchema.generated";
import type { ContainerInputData } from "@/forms/validation";
import type {
  ComposeMappingResult,
  ComposeServiceData,
  ComposeServiceExtras,
  MappingContext,
} from "./composeTypes";
import {
  asRecord,
  asStringArray,
  clone,
  commandToString,
  deviceMappingFromEntry,
  envToKeyValuePairs,
  extraHostsFromValue,
  formatSchemaIssues,
  healthcheckTestToString,
  isBindSource,
  labelToId,
  listOrDictToPairs,
  parseBlkioEntries,
  parseDurationToNs,
  parseDurationToSec,
  parseIntValue,
  parseMemory,
  parseUlimits,
  portBindingFromEntry,
  restartPolicyToEdgehog,
  splitVolumeShortSyntax,
  stringOrStringList,
  SUPPORTED_SERVICE_KEYS,
  toInt,
} from "./composeUtils";

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
      tmpfs: asStringArray(service.tmpfs).map((entry) => {
        const separator = entry.indexOf(":");

        return separator === -1
          ? { path: entry }
          : {
              path: entry.slice(0, separator),
              options: entry.slice(separator + 1) || undefined,
            };
      }),
      readOnlyRootfs: service.read_only === true,
      privileged: service.privileged === true,
      capAdd: asStringArray(service.cap_add) as ContainerInputData["capAdd"],
      capDrop: asStringArray(service.cap_drop) as ContainerInputData["capDrop"],
      volumeDriver:
        typeof service.volume_driver === "string"
          ? service.volume_driver
          : undefined,
      storageOpts: Object.entries(asRecord(service.storage_opt)).map(
        ([key, value]) => ({ key, value: String(value) }),
      ),
      env: envToKeyValuePairs(service.environment),
      restartPolicy: undefined,
      user:
        typeof service.user === "string" && service.user.trim() !== ""
          ? service.user
          : undefined,
      workingDirectory:
        typeof service.working_dir === "string" &&
        service.working_dir.trim() !== ""
          ? service.working_dir
          : undefined,
      command: commandToString(service.command),
      entrypoint: commandToString(service.entrypoint),
      labels: listOrDictToPairs(service.labels),
      sysctls: listOrDictToPairs(service.sysctls),
      domainname:
        typeof service.domainname === "string" &&
        service.domainname.trim() !== ""
          ? service.domainname
          : undefined,
      dns: stringOrStringList(service.dns),
      dnsSearch: stringOrStringList(service.dns_search),
      dnsOptions: asStringArray(service.dns_opt),
      exposedPorts: stringOrStringList(service.expose),
      cpuShares: toInt(service.cpu_shares),
      cpusetCpus:
        typeof service.cpuset === "string" && service.cpuset.trim() !== ""
          ? service.cpuset
          : undefined,
      shmSize: parseMemory(service.shm_size),
      oomScoreAdjustment: toInt(service.oom_score_adj),
      cgroupsMode:
        service.cgroup === "host" || service.cgroup === "private"
          ? service.cgroup
          : undefined,
      ipcMode:
        typeof service.ipc === "string" && service.ipc.trim() !== ""
          ? service.ipc
          : undefined,
      usernsMode:
        typeof service.userns_mode === "string" &&
        service.userns_mode.trim() !== ""
          ? service.userns_mode
          : undefined,
      pidMode:
        typeof service.pid === "string" && service.pid.trim() !== ""
          ? service.pid
          : undefined,
      securityopt: asStringArray(service.security_opt),
      groupAdd: stringOrStringList(service.group_add),
      deviceCgroupRules: asStringArray(service.device_cgroup_rules),
      runtime:
        typeof service.runtime === "string" && service.runtime.trim() !== ""
          ? service.runtime
          : undefined,
      stopSignal:
        typeof service.stop_signal === "string" &&
        service.stop_signal.trim() !== ""
          ? service.stop_signal
          : undefined,
      networks: [],
      deviceMappings: [],
      deviceRequests: [],
      fileMounts: [],
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
      const { policy, count, warning } = restartPolicyToEdgehog(
        service.restart,
      );

      container.restartPolicy = policy;
      container.restartPolicyMaximumRetryCount = count;

      if (warning) warnings.push(`${ctx}: restart ${warning}`);
    }

    // healthcheck
    if (
      service.healthcheck != null &&
      typeof service.healthcheck === "object" &&
      !Array.isArray(service.healthcheck)
    ) {
      const healthcheck = asRecord(service.healthcheck);

      if (healthcheck.test !== undefined) {
        if (Array.isArray(healthcheck.test) && healthcheck.test[0] === "CMD") {
          warnings.push(
            `${ctx}: healthcheck exec form is normalized to shell form`,
          );
        }

        container.healthcheckTest = healthcheckTestToString(healthcheck.test);
      }

      if (healthcheck.disable === true) {
        warnings.push(
          `${ctx}: healthcheck disable is not supported and will be ignored`,
        );
      }

      const durations: {
        field:
          | "healthcheckInterval"
          | "healthcheckTimeout"
          | "healthcheckStartPeriod"
          | "healthcheckStartInterval";
        raw: unknown;
      }[] = [
        { field: "healthcheckInterval", raw: healthcheck.interval },
        { field: "healthcheckTimeout", raw: healthcheck.timeout },
        { field: "healthcheckStartPeriod", raw: healthcheck.start_period },
        { field: "healthcheckStartInterval", raw: healthcheck.start_interval },
      ];

      for (const { field, raw } of durations) {
        if (raw == null) continue;

        const parsed = parseDurationToNs(raw);

        if (parsed === undefined) {
          warnings.push(
            `${ctx}: unsupported healthcheck duration '${String(raw)}' is not supported and will be ignored`,
          );

          continue;
        }

        container[field] = parsed;
      }

      if (healthcheck.retries != null) {
        const retries =
          typeof healthcheck.retries === "number"
            ? healthcheck.retries
            : typeof healthcheck.retries === "string" &&
                healthcheck.retries.trim() !== ""
              ? Number(healthcheck.retries)
              : undefined;

        if (
          retries === undefined ||
          !Number.isInteger(retries) ||
          retries < 0
        ) {
          warnings.push(
            `${ctx}: unsupported healthcheck retries '${String(healthcheck.retries)}' is not supported and will be ignored`,
          );
        } else {
          container.healthcheckRetries = retries;
        }
      }
    } else if (service.healthcheck != null) {
      warnings.push(
        `${ctx}: unsupported healthcheck definition is not supported and will be ignored`,
      );
    }

    // ulimits
    if (service.ulimits != null) {
      container.ulimits = parseUlimits(service.ulimits, ctx, warnings);
    }

    // logging
    if (
      service.logging != null &&
      typeof service.logging === "object" &&
      !Array.isArray(service.logging)
    ) {
      const logging = asRecord(service.logging);

      if (typeof logging.driver === "string") {
        container.logType = logging.driver;
      }

      if (logging.options != null) {
        container.logConfig = Object.entries(asRecord(logging.options)).map(
          ([key, val]) => ({
            key,
            value: val == null ? "" : String(val),
          }),
        );
      }
    } else if (service.logging != null) {
      warnings.push(
        `${ctx}: unsupported logging definition is not supported and will be ignored`,
      );
    }

    // blkio_config
    if (
      service.blkio_config != null &&
      typeof service.blkio_config === "object" &&
      !Array.isArray(service.blkio_config)
    ) {
      const blkio = asRecord(service.blkio_config);
      const unsupportedBlkioOptions = Object.keys(blkio).filter(
        (key) =>
          ![
            "weight",
            "weight_device",
            "device_read_bps",
            "device_write_bps",
            "device_read_iops",
            "device_write_iops",
          ].includes(key),
      );

      if (unsupportedBlkioOptions.length > 0) {
        warnings.push(
          `${ctx}: blkio_config option(s) ${unsupportedBlkioOptions.join(", ")} are not supported and will be ignored`,
        );
      }

      if (blkio.weight != null) {
        const weight = toInt(blkio.weight);

        if (weight === undefined) {
          warnings.push(
            `${ctx}: unsupported blkio weight '${String(blkio.weight)}' is not supported and will be ignored`,
          );
        } else {
          container.blkioWeight = weight;
        }
      }

      container.blkioWeightDevice = parseBlkioEntries(
        blkio.weight_device,
        "weight",
        ctx,
        warnings,
      ).map(({ path, value }) => ({ path, weight: value }));
      container.blkioDeviceReadBps = parseBlkioEntries(
        blkio.device_read_bps,
        "rate",
        ctx,
        warnings,
      ).map(({ path, value }) => ({ path, rate: value }));
      container.blkioDeviceWriteBps = parseBlkioEntries(
        blkio.device_write_bps,
        "rate",
        ctx,
        warnings,
      ).map(({ path, value }) => ({ path, rate: value }));
      container.blkioDeviceReadIops = parseBlkioEntries(
        blkio.device_read_iops,
        "rate",
        ctx,
        warnings,
      ).map(({ path, value }) => ({ path, rate: value }));
      container.blkioDeviceWriteIops = parseBlkioEntries(
        blkio.device_write_iops,
        "rate",
        ctx,
        warnings,
      ).map(({ path, value }) => ({ path, rate: value }));
    } else if (service.blkio_config != null) {
      warnings.push(
        `${ctx}: unsupported blkio_config definition is not supported and will be ignored`,
      );
    }

    // stop timeout (compose duration -> whole seconds)
    if (service.stop_grace_period != null) {
      const stopTimeout = parseDurationToSec(service.stop_grace_period);

      if (stopTimeout === undefined) {
        warnings.push(
          `${ctx}: unsupported stop_grace_period '${String(service.stop_grace_period)}' is not supported and will be ignored`,
        );
      } else {
        container.stopTimeout = stopTimeout;
      }
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
                  Array.isArray(capability)
                    ? asStringArray(capability)
                    : typeof capability === "string"
                      ? [capability]
                      : [],
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
