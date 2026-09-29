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

import { stringify } from "yaml";

import type {
  MappingContext,
  ReleaseComposeData,
  SerializeOptions,
  SerializeResult,
} from "./composeTypes";
import {
  clone,
  formatNsToDuration,
  formatSecToDuration,
  healthcheckTestToCompose,
  idToLabel,
  pairsToMap,
  restartPolicyToCompose,
  sameStrings,
} from "./composeUtils";

/* ------------------------- form data -> YAML ------------------------- */

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
    if (container.domainname) output.domainname = container.domainname;
    if (container.networkMode) output.network_mode = container.networkMode;
    if (container.user) output.user = container.user;
    if (container.workingDirectory)
      output.working_dir = container.workingDirectory;
    if (container.command) output.command = container.command;
    if (container.entrypoint) output.entrypoint = container.entrypoint;
    if (container.stopSignal) output.stop_signal = container.stopSignal;
    if (container.stopTimeout != null)
      output.stop_grace_period = formatSecToDuration(container.stopTimeout);
    if (container.runtime) output.runtime = container.runtime;

    const restart = restartPolicyToCompose(
      container.restartPolicy,
      container.restartPolicyMaximumRetryCount,
    );

    if (restart) output.restart = restart;

    if (container.privileged) output.privileged = true;
    if (container.readOnlyRootfs) output.read_only = true;

    if (container.portBindings?.length) {
      output.ports = [...container.portBindings];
    }

    if (container.extraHosts?.length) {
      output.extra_hosts = [...container.extraHosts];
    }

    if (container.dns?.length) {
      output.dns = [...container.dns];
    }

    if (container.dnsSearch?.length) {
      output.dns_search = [...container.dnsSearch];
    }

    if (container.dnsOptions?.length) {
      output.dns_opt = [...container.dnsOptions];
    }

    if (container.exposedPorts?.length) {
      output.expose = [...container.exposedPorts];
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

    if (container.tmpfs?.length) {
      output.tmpfs = container.tmpfs.map((entry) =>
        entry.options ? `${entry.path}:${entry.options}` : entry.path,
      );
    }

    if (container.storageOpts?.length) {
      output.storage_opt = Object.fromEntries(
        container.storageOpts.map((entry: { key: string; value: string }) => [
          entry.key,
          entry.value,
        ]),
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
    if (container.cpuShares != null) output.cpu_shares = container.cpuShares;
    if (container.cpusetCpus) output.cpuset = container.cpusetCpus;
    if (container.shmSize != null) output.shm_size = container.shmSize;
    if (container.oomScoreAdjustment != null)
      output.oom_score_adj = container.oomScoreAdjustment;
    if (container.cpuRealtimePeriod != null)
      output.cpu_rt_period = container.cpuRealtimePeriod;
    if (container.cpuRealtimeRuntime != null)
      output.cpu_rt_runtime = container.cpuRealtimeRuntime;

    if (container.capAdd?.length) output.cap_add = [...container.capAdd];
    if (container.capDrop?.length) output.cap_drop = [...container.capDrop];
    if (container.cgroupsMode) output.cgroup = container.cgroupsMode;
    if (container.ipcMode) output.ipc = container.ipcMode;
    if (container.usernsMode) output.userns_mode = container.usernsMode;
    if (container.pidMode) output.pid = container.pidMode;
    if (container.securityopt?.length)
      output.security_opt = [...container.securityopt];
    if (container.groupAdd?.length) output.group_add = [...container.groupAdd];
    if (container.deviceCgroupRules?.length)
      output.device_cgroup_rules = [...container.deviceCgroupRules];

    if (container.labels?.length) {
      output.labels = pairsToMap(container.labels);
    }

    if (container.sysctls?.length) {
      output.sysctls = pairsToMap(container.sysctls);
    }

    if (container.ulimits?.length) {
      output.ulimits = Object.fromEntries(
        container.ulimits.map((ulimit) =>
          ulimit.soft === ulimit.hard
            ? [ulimit.name, ulimit.soft]
            : [ulimit.name, { soft: ulimit.soft, hard: ulimit.hard }],
        ),
      );
    }

    if (container.logType || container.logConfig?.length) {
      const logging: Record<string, unknown> = {};

      if (container.logType) logging.driver = container.logType;
      if (container.logConfig?.length)
        logging.options = pairsToMap(container.logConfig);

      output.logging = logging;
    }

    if (
      container.blkioWeight != null ||
      container.blkioWeightDevice?.length ||
      container.blkioDeviceReadBps?.length ||
      container.blkioDeviceWriteBps?.length ||
      container.blkioDeviceReadIops?.length ||
      container.blkioDeviceWriteIops?.length
    ) {
      const blkioConfig: Record<string, unknown> = {};

      if (container.blkioWeight != null)
        blkioConfig.weight = container.blkioWeight;
      if (container.blkioWeightDevice?.length)
        blkioConfig.weight_device = container.blkioWeightDevice.map(
          ({ path, weight }) => ({ path, weight }),
        );
      if (container.blkioDeviceReadBps?.length)
        blkioConfig.device_read_bps = container.blkioDeviceReadBps.map(
          ({ path, rate }) => ({ path, rate }),
        );
      if (container.blkioDeviceWriteBps?.length)
        blkioConfig.device_write_bps = container.blkioDeviceWriteBps.map(
          ({ path, rate }) => ({ path, rate }),
        );
      if (container.blkioDeviceReadIops?.length)
        blkioConfig.device_read_iops = container.blkioDeviceReadIops.map(
          ({ path, rate }) => ({ path, rate }),
        );
      if (container.blkioDeviceWriteIops?.length)
        blkioConfig.device_write_iops = container.blkioDeviceWriteIops.map(
          ({ path, rate }) => ({ path, rate }),
        );

      output.blkio_config = blkioConfig;
    }

    if (
      container.healthcheckTest != null ||
      container.healthcheckInterval != null ||
      container.healthcheckTimeout != null ||
      container.healthcheckRetries != null ||
      container.healthcheckStartPeriod != null ||
      container.healthcheckStartInterval != null
    ) {
      const healthcheck: Record<string, unknown> = {};
      const test = healthcheckTestToCompose(container.healthcheckTest);

      if (test !== undefined) healthcheck.test = test;
      if (container.healthcheckInterval != null)
        healthcheck.interval = formatNsToDuration(
          container.healthcheckInterval,
        );
      if (container.healthcheckTimeout != null)
        healthcheck.timeout = formatNsToDuration(container.healthcheckTimeout);
      if (container.healthcheckRetries != null)
        healthcheck.retries = container.healthcheckRetries;
      if (container.healthcheckStartPeriod != null)
        healthcheck.start_period = formatNsToDuration(
          container.healthcheckStartPeriod,
        );
      if (container.healthcheckStartInterval != null)
        healthcheck.start_interval = formatNsToDuration(
          container.healthcheckStartInterval,
        );

      output.healthcheck = healthcheck;
    }

    const env: unknown = container.env;

    if (Array.isArray(env) && env.length) {
      output.environment = Object.fromEntries(
        env.map((entry) => [entry.key, entry.value]),
      );
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

    if (container.fileMounts?.length) {
      warnings.push(
        `${ctx}: file mounts are configured from the form only and are not part of the compose file`,
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
