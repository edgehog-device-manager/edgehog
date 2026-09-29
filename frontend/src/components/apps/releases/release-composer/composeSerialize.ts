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
  healthcheckTestToCompose,
  idToLabel,
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
    if (container.networkMode) output.network_mode = container.networkMode;
    if (container.user) output.user = container.user;
    if (container.workingDirectory)
      output.working_dir = container.workingDirectory;
    if (container.command) output.command = container.command;
    if (container.entrypoint) output.entrypoint = container.entrypoint;

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
    if (container.cpuRealtimePeriod != null)
      output.cpu_rt_period = container.cpuRealtimePeriod;
    if (container.cpuRealtimeRuntime != null)
      output.cpu_rt_runtime = container.cpuRealtimeRuntime;

    if (container.capAdd?.length) output.cap_add = [...container.capAdd];
    if (container.capDrop?.length) output.cap_drop = [...container.capDrop];

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
