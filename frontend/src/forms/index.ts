/*
  This file is part of Edgehog.

  Copyright 2021 - 2025 SECO Mind Srl

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

import * as yup from "yup";
import { defineMessages } from "react-intl";
import semverValid from "semver/functions/valid";
import semverValidRange from "semver/ranges/valid";

import { CapAddList, CapDropList } from "forms/CreateRelease";

/* ----------------------------- Field Explanations ----------------------------- */
const fieldExplanations = defineMessages({
  imageReferenceTitle: {
    id: "fieldExplanation.imageReference.title",
    defaultMessage: "Image Reference",
  },
  imageReferenceDescription: {
    id: "fieldExplanation.imageReference.description",
    defaultMessage:
      "The complete reference for the container image you want to use, including registry, repository, and tag.",
  },
  imageReferenceExample: {
    id: "fieldExplanation.imageReference.example",
    defaultMessage: "my-image:latest or registry.example.com/my-app:v1.0",
  },
  imageCredentialsTitle: {
    id: "fieldExplanation.imageCredentials.title",
    defaultMessage: "Image Credentials",
  },
  imageCredentialsDescription: {
    id: "fieldExplanation.imageCredentials.description",
    defaultMessage:
      "Select credentials needed to pull this image from a private registry. Leave empty for public images.",
  },
  hostnameTitle: {
    id: "fieldExplanation.hostname.title",
    defaultMessage: "Hostname",
  },
  hostnameDescription: {
    id: "fieldExplanation.hostname.description",
    defaultMessage:
      "The network hostname to assign to the container, which must comply with RFC 1123.",
  },
  hostnameExample: {
    id: "fieldExplanation.hostname.example",
    defaultMessage: "web-server-1",
  },
  restartPolicyTitle: {
    id: "fieldExplanation.restartPolicy.title",
    defaultMessage: "Restart Policy",
  },
  restartPolicyDescription: {
    id: "fieldExplanation.restartPolicy.description",
    defaultMessage:
      "Defines container restart behavior. Options: 'no' (never restart), 'always', 'unless-stopped', 'on-failure'.",
  },
  restartPolicyExample: {
    id: "fieldExplanation.restartPolicy.example",
    defaultMessage: "unless-stopped",
  },
  networkModeTitle: {
    id: "fieldExplanation.networkMode.title",
    defaultMessage: "Network Mode",
  },
  networkModeDescription: {
    id: "fieldExplanation.networkMode.description",
    defaultMessage:
      "Supported standard values are: bridge, host, none, and container:'<name|id>'. Any other value is taken as a custom network's name to which this container should connect to. If you are using a different container engine than docker, there could be other values.",
  },
  networkModeExample: {
    id: "fieldExplanation.networkMode.example",
    defaultMessage: "bridge",
  },
  networksTitle: {
    id: "fieldExplanation.networks.title",
    defaultMessage: "Attached Networks",
  },
  networksDescription: {
    id: "fieldExplanation.networks.description",
    defaultMessage:
      "Select custom networks the container should connect to, usually for inter-service communication.",
  },
  portBindingsTitle: {
    id: "fieldExplanation.portBindings.title",
    defaultMessage: "Port Bindings",
  },
  portBindingsDescription: {
    id: "fieldExplanation.portBindings.description",
    defaultMessage:
      "Maps host ports to container ports for external access. Format: host_port:container_port.",
  },
  portBindingsExample: {
    id: "fieldExplanation.portBindings.example",
    defaultMessage: "8080:80,443:443",
  },
  bindsTitle: {
    id: "fieldExplanation.binds.title",
    defaultMessage: "Binds",
  },
  bindsDescription: {
    id: "fieldExplanation.binds.description",
    defaultMessage:
      "Maps host ports to container ports for external access. Format: [host_port:]container_port[/protocol]. Protocol is TCP by default",
  },
  bindsExample: {
    id: "fieldExplanation.binds.example",
    defaultMessage: "/data:/data, /config:/config:ro",
  },
  extraHostsTitle: {
    id: "fieldExplanation.extraHosts.title",
    defaultMessage: "Extra Hosts",
  },
  extraHostsDescription: {
    id: "fieldExplanation.extraHosts.description",
    defaultMessage:
      "List of hostname/IP mappings added to the container's /etc/hosts for custom DNS resolution. 'host-gateway' resolves to the host IP.",
  },
  extraHostsExample: {
    id: "fieldExplanation.extraHosts.example",
    defaultMessage: '["database:192.168.1.5", "gateway:host-gateway"]',
  },
  memoryTitle: {
    id: "fieldExplanation.memory.title",
    defaultMessage: "Memory Limit (bytes)",
  },
  memoryDescription: {
    id: "fieldExplanation.memory.description",
    defaultMessage:
      "Maximum physical memory the container can use. Set 0 for unlimited memory.",
  },
  memoryExample: {
    id: "fieldExplanation.memory.example",
    defaultMessage: "104857600 (100MB)",
  },
  memoryReservationTitle: {
    id: "fieldExplanation.memoryReservation.title",
    defaultMessage: "Memory Reservation (bytes)",
  },
  memoryReservationDescription: {
    id: "fieldExplanation.memoryReservation.description",
    defaultMessage:
      "Allows you to specify a soft limit smaller than Memory which is activated when Docker detects contention or low memory on the host machine. " +
      "If you use Memory Reservation, it must be set lower than Memory for it to take precedence. " +
      "Because it is a soft limit, it doesn't guarantee that the container doesn't exceed the limit.",
  },
  memoryReservationExample: {
    id: "fieldExplanation.memoryReservation.example",
    defaultMessage: "104857600 (100MB)",
  },
  memorySwapTitle: {
    id: "fieldExplanation.memorySwap.title",
    defaultMessage: "Memory + Swap Limit (bytes)",
  },
  memorySwapDescription: {
    id: "fieldExplanation.memorySwap.description",
    defaultMessage:
      "The total amount of memory plus swap the container can use. If memorySwap is set to a positive value, both Memory and Memory Swap must be set. " +
      "Memory controls the amount of physical memory, and Memory Swap represents the combined limit of memory and swap. " +
      "For example, if memory='300m' and memorySwap='1g', the container can use 300MB of memory and 700MB of swap (1GB - 300MB).",
  },
  memorySwapExample: {
    id: "fieldExplanation.memorySwap.example",
    defaultMessage: "1073741824 (1GB)",
  },
  memorySwappinessTitle: {
    id: "fieldExplanation.memorySwappiness.title",
    defaultMessage: "Memory Swappiness (0-100)",
  },
  memorySwappinessDescription: {
    id: "fieldExplanation.memorySwappiness.description",
    defaultMessage:
      "Controls kernel swap behavior. 0 = avoid swapping, 100 = swap aggressively.",
  },
  memorySwappinessExample: {
    id: "fieldExplanation.memorySwappiness.example",
    defaultMessage: "60",
  },
  cpuPeriodTitle: {
    id: "fieldExplanation.cpuPeriod.title",
    defaultMessage: "CPU Period (microseconds)",
  },
  cpuPeriodDescription: {
    id: "fieldExplanation.cpuPeriod.description",
    defaultMessage:
      "Duration of a CPU scheduling period. Used with CPU Quota to limit CPU usage.",
  },
  cpuPeriodExample: {
    id: "fieldExplanation.cpuPeriod.example",
    defaultMessage: "100000",
  },
  cpuQuotaTitle: {
    id: "fieldExplanation.cpuQuota.title",
    defaultMessage: "CPU Quota (microseconds)",
  },
  cpuQuotaDescription: {
    id: "fieldExplanation.cpuQuota.description",
    defaultMessage:
      "CPU time allowed per period. Example: quota 50000 with period 100000 → 50% of one CPU.",
  },
  cpuQuotaExample: {
    id: "fieldExplanation.cpuQuota.example",
    defaultMessage: "50000",
  },
  cpuRealtimePeriodTitle: {
    id: "fieldExplanation.cpuRealtimePeriod.title",
    defaultMessage: "CPU Real-Time Period (microseconds)",
  },
  cpuRealtimePeriodDescription: {
    id: "fieldExplanation.cpuRealtimePeriod.description",
    defaultMessage:
      "Scheduling period for CPU time dedicated to real-time tasks. Set to 0 to allocate no time allocated to real-time tasks.",
  },
  cpuRealtimePeriodExample: {
    id: "fieldExplanation.cpuRealtimePeriod.example",
    defaultMessage: "1000000",
  },
  cpuRealtimeRuntimeTitle: {
    id: "fieldExplanation.cpuRealtimeRuntime.title",
    defaultMessage: "CPU Real-Time Runtime (microseconds)",
  },
  cpuRealtimeRuntimeDescription: {
    id: "fieldExplanation.cpuRealtimeRuntime.description",
    defaultMessage:
      "Max real-time CPU time within the real-time period. Cannot exceed the real-time period.",
  },
  cpuRealtimeRuntimeExample: {
    id: "fieldExplanation.cpuRealtimeRuntime.example",
    defaultMessage: "950000",
  },
  envTitle: {
    id: "fieldExplanation.env.title",
    defaultMessage: "Environment Variables (JSON String)",
  },
  envDescription: {
    id: "fieldExplanation.env.description",
    defaultMessage:
      "JSON array of environment variables in 'KEY=VALUE' format, used to pass config to the containerized app.",
  },
  envExample: {
    id: "fieldExplanation.env.example",
    defaultMessage: '["NODE_ENV=production", "PORT=8080"]',
  },
  volumesTitle: {
    id: "fieldExplanation.volumes.title",
    defaultMessage: "Volume Mounts",
  },
  volumesDescription: {
    id: "fieldExplanation.volumes.description",
    defaultMessage:
      "Attach an existing volume to a path inside the container. This allows the container to persist data or share it with other containers. " +
      "You only need to select the volume and provide the container path where it will be mounted.",
  },
  volumesExample: {
    id: "fieldExplanation.volumes.example",
    defaultMessage: "my-named-volume:/app/data",
  },
  privilegedTitle: {
    id: "fieldExplanation.privileged.title",
    defaultMessage: "Privileged Mode",
  },
  privilegedDescription: {
    id: "fieldExplanation.privileged.description",
    defaultMessage:
      "Run container with extended privileges, giving full host resource access (like root).",
  },
  readOnlyRootfsTitle: {
    id: "fieldExplanation.readOnlyRootfs.title",
    defaultMessage: "Read-Only Root Filesystem",
  },
  readOnlyRootfsDescription: {
    id: "fieldExplanation.readOnlyRootfs.description",
    defaultMessage:
      "Prevents modification of system files by making the container's root filesystem read-only.",
  },
  storageOptTitle: {
    id: "fieldExplanation.storageOpt.title",
    defaultMessage: "Storage Options",
  },
  storageOptDescription: {
    id: "fieldExplanation.storageOpt.description",
    defaultMessage:
      "Options for the storage driver, e.g., limit writable layer size.",
  },
  storageOptExample: {
    id: "fieldExplanation.storageOpt.example",
    defaultMessage: '["size=100G"]',
  },
  tmpfsTitle: {
    id: "fieldExplanation.tmpfs.title",
    defaultMessage: "Tmpfs Mounts",
  },
  tmpfsDescription: {
    id: "fieldExplanation.tmpfs.description",
    defaultMessage:
      "In-memory filesystems mounted at specified paths. Data is fast but lost on container restart.",
  },
  tmpfsExample: {
    id: "fieldExplanation.tmpfs.example",
    defaultMessage: '["/tmp:size=64m"]',
  },
  capAddTitle: {
    id: "fieldExplanation.capAdd.title",
    defaultMessage: "Add Capabilities (Cap Add)",
  },
  capAddDescription: {
    id: "fieldExplanation.capAdd.description",
    defaultMessage:
      "Add Linux kernel capabilities to the container, e.g., 'NET_ADMIN' for network management.",
  },
  capAddExample: {
    id: "fieldExplanation.capAdd.example",
    defaultMessage: '["NET_ADMIN", "SYS_ADMIN"]',
  },
  capDropTitle: {
    id: "fieldExplanation.capDrop.title",
    defaultMessage: "Drop Capabilities (Cap Drop)",
  },
  capDropDescription: {
    id: "fieldExplanation.capDrop.description",
    defaultMessage:
      "Remove default Linux kernel capabilities to improve container security.",
  },
  capDropExample: {
    id: "fieldExplanation.capDrop.example",
    defaultMessage: '["MKNOD", "SETPCAP"]',
  },
  volumeDriverTitle: {
    id: "fieldExplanation.volumeDriver.title",
    defaultMessage: "Volume Driver",
  },
  volumeDriverDescription: {
    id: "fieldExplanation.volumeDriver.description",
    defaultMessage: "Driver/plugin used to manage and mount volumes.",
  },
  volumeDriverExample: {
    id: "fieldExplanation.volumeDriver.example",
    defaultMessage: "local",
  },
  deviceMappingsTitle: {
    id: "fieldExplanation.deviceMappings.title",
    defaultMessage: "Device Mappings",
  },
  deviceMappingsDescription: {
    id: "fieldExplanation.deviceMappings.description",
    defaultMessage:
      "Maps host devices to container paths with specific access permissions.",
  },
  deviceMappingsExample: {
    id: "fieldExplanation.deviceMappings.example",
    defaultMessage:
      '[("pathOnHost":"/dev/sda1","pathInContainer":"/dev/storage","cGroupPermissions":"mrw")]',
  },
});

/* ----------------------------- Validation Messages ----------------------------- */
const messages = defineMessages({
  required: {
    id: "validation.required",
    defaultMessage: "Required.",
  },
  unique: {
    id: "validation.unique",
    defaultMessage: "Duplicate value.",
  },
  arrayMin: {
    id: "validation.array.min",
    defaultMessage: "Does not have enough values.",
  },
  handleFormat: {
    id: "validation.handle.format",
    defaultMessage:
      "The handle must start with a letter and only contain lower case characters, numbers or the hyphen symbol -",
  },
  baseImageFileSchema: {
    id: "validation.baseImageFile.required",
    defaultMessage: "Required.",
  },
  baseImageVersionFormat: {
    id: "validation.baseImageVersion.format",
    defaultMessage: "The version must follow the Semantic Versioning spec",
  },
  baseImageStartingVersionRequirementFormat: {
    id: "validation.baseImageStartingVersionRequirement.format",
    defaultMessage:
      "The supported starting versions must be a valid version range",
  },
  number: {
    id: "validation.number",
    defaultMessage: "{label} must be a number.",
  },
  numberMin: {
    id: "validation.number.min",
    defaultMessage: "{label} must be greater than or equal to {min}.",
  },
  numberMax: {
    id: "validation.number.max",
    defaultMessage: "{label} must be less than or equal to {max}.",
  },
  numberPositive: {
    id: "validation.number.positive",
    defaultMessage: "{label} must be a positive number.",
  },
  numberInteger: {
    id: "validation.number.integer",
    defaultMessage: "{label} must be an integer.",
  },
  envInvalidJson: {
    id: "validation.env.invalidJson",
    defaultMessage: "Must be a valid JSON string.",
  },
  envInvalidIsNested: {
    id: "validation.env.invalidIsNested",
    defaultMessage: "Environment Variables' values cannot be nested.",
  },
  portBindingsFormat: {
    id: "validation.portBindings.format",
    defaultMessage:
      "Port Bindings must be comma-separated values in the format [HOST:]CONTAINER[/PROTOCOL]",
  },
  bindsInvalid: {
    id: "validation.binds.format",
    defaultMessage:
      "Each bind must be in the format hostDir:containerDir[:options], separated by commas.",
  },
  extraHostsFormat: {
    id: "validation.extraHosts.format",
    defaultMessage: "Must be in the form hostname:IP (e.g., myhost:127.0.0.1)",
  },
  tmpfsFormat: {
    id: "validation.tmpfs.format",
    defaultMessage:
      'Must be a valid JSON array of strings in the format "/path=option1,option2", e.g. ["/run=rw,size=64m"]',
  },
  storageFormat: {
    id: "validation.storage.format",
    defaultMessage:
      'Must be a valid JSON array of strings in the format "key=value", e.g. ["size=120G"]',
  },
  memorySwap: {
    id: "validation.memorySwapInvalid",
    defaultMessage: "Memory Swap must be greater than/equal to Memory.",
  },
  cpuQuotaPeriod: {
    id: "validation.cpuQuotaPeriod.format",
    defaultMessage:
      "CPU Period and CPU Quota must be either both set or both unset",
  },
});

/* ----------------------------- Labels ----------------------------- */
const labels = defineMessages({
  memory: {
    id: "labels.memoryLabel",
    defaultMessage: "Memory (bytes)",
  },
  memoryReservation: {
    id: "labels.memoryReservationLabel",
    defaultMessage: "Memory Reservation (bytes)",
  },
  memorySwap: {
    id: "labels.memorySwapLabel",
    defaultMessage: "Memory Swap (bytes)",
  },
  memorySwappiness: {
    id: "fieldExplanation.memorySwappiness.title",
    defaultMessage: "Memory Swappiness (0-100)",
  },
  cpuPeriod: {
    id: "labels.cpuPeriodLabel",
    defaultMessage: "CPU Period (µs)",
  },
  cpuQuota: {
    id: "labels.cpuQuotaLabel",
    defaultMessage: "CPU Quota (µs)",
  },
  cpuRealtimePeriod: {
    id: "labels.cpuRealtimePeriodLabel",
    defaultMessage: "CPU Realtime Period (µs)",
  },
  cpuRealtimeRuntime: {
    id: "labels.cpuRealtimeRuntimeLabel",
    defaultMessage: "CPU Realtime Runtime (µs)",
  },
});

/* ----------------------------- Yup Locale ----------------------------- */
yup.setLocale({
  mixed: { required: messages.required.id },
  array: { min: messages.arrayMin.id },
  number: {
    integer: (values) => ({ messageId: messages.numberInteger.id, values }),
    min: (values) => ({ messageId: messages.numberMin.id, values }),
    max: (values) => ({ messageId: messages.numberMax.id, values }),
    positive: (values) => ({ messageId: messages.numberPositive.id, values }),
  },
});

/* ----------------------------- Reusable Schemas ----------------------------- */
const handleSchema = yup
  .string()
  .matches(/^[a-z][a-z\d-]*$/, messages.handleFormat.id);

const nullableTrimString = yup
  .string()
  .nullable()
  .transform((value) => value?.trim());

const numberSchema = yup
  .number()
  .typeError((values) => ({ messageId: messages.number.id, values }));

const optionalNumberSchema = yup
  .number()
  .transform((value, originalValue) => {
    if (originalValue === "" || originalValue == null || Number.isNaN(value))
      return undefined;
    return value;
  })
  .typeError((values) => ({ messageId: messages.number.id, values }));

/* ----------------------------- Array Helpers ----------------------------- */
type ArrayType = any[] | null | undefined;

function distinctOnProperty<
  TIn extends ArrayType,
  TContext,
  TDefault = undefined,
  TFlags extends yup.Flags = "",
>(this: yup.ArraySchema<TIn, TContext, TDefault, TFlags>, property: string) {
  return this.test("distinct-on-property", (array, context) => {
    if (!array) return true;

    const errors: yup.ValidationError[] = [];
    const duplicateProperties = array
      .filter(
        (e, i) => array.findIndex((e2) => e2[property] === e[property]) !== i,
      )
      .map((e) => e[property]);

    for (let i = 0; i < array.length; ++i) {
      const element = array[i];
      if (
        element[property] !== "" &&
        duplicateProperties.includes(element[property])
      ) {
        errors.push(
          new yup.ValidationError(
            messages.unique.id,
            element,
            `${context.path}[${i}].${property}`,
          ),
        );
      }
    }

    if (errors.length > 0)
      return context.createError({ message: () => errors });

    return true;
  });
}

yup.addMethod(yup.array, "distinctOnProperty", distinctOnProperty);

declare module "yup" {
  interface ArraySchema<
    TIn extends ArrayType,
    TContext,
    TDefault = undefined,
    TFlags extends yup.Flags = "",
  > {
    distinctOnProperty(
      property: string,
    ): ArraySchema<TIn, TContext, TDefault, TFlags>;
  }
}

/* ----------------------------- Component Specific Schemas ----------------------------- */
const baseImageFileSchema = yup.mixed().test({
  name: "fileRequired",
  message: messages.baseImageFileSchema.id,
  test: (value) => value instanceof FileList && value.length > 0,
});

const baseImageVersionSchema = yup.string().test({
  name: "versionFormat",
  message: messages.baseImageVersionFormat.id,
  test: (value) => semverValid(value) !== null,
});

const baseImageStartingVersionRequirementSchema = yup.string().test({
  name: "startingVersionRequirementFormat",
  message: messages.baseImageStartingVersionRequirementFormat.id,
  test: (value) => semverValidRange(value) !== null,
});

interface KeyValueMaybeNested {
  key: string;
  value: any;
}
export interface KeyValue<T> extends KeyValueMaybeNested {
  value: T;
}

const isValidJson = (value: string) => {
  try {
    JSON.parse(value);
    return true;
  } catch {
    return false;
  }
};

const isNotNested = (
  value: KeyValueMaybeNested[] | string,
): value is KeyValueMaybeNested[] => {
  return (value as KeyValueMaybeNested[])
    .map(({ key: _, value: val }) => val)
    .reduce(
      (acc: boolean, curr) =>
        acc && ["number", "boolean", "string"].includes(typeof curr),
      true,
    );
};

const envSchema = yup
  .mixed<string | KeyValueMaybeNested[]>()
  .nullable()
  .transform((value) => (typeof value === "string" ? value?.trim() : value))
  .transform((value) => {
    if (typeof value === "string" && isValidJson(value)) {
      return Object.entries(JSON.parse(value)).map(
        ([key, val]) => ({ key, value: val }) as KeyValueMaybeNested,
      );
    }
    return value;
  })
  .test({
    name: "is-json",
    message: messages.envInvalidJson.id,
    test: (value) =>
      value && typeof value === "string" ? isValidJson(value) : true,
  })
  .test({
    name: "is-not-nested",
    message: messages.envInvalidIsNested.id,
    test: (value) => (value ? isNotNested(value) : true),
  })
  .default("{}");

const optionsSchema = yup
  .string()
  .nullable()
  .transform((value) => value?.trim())
  .test({
    name: "is-json",
    message: messages.envInvalidJson.id,
    test: (value) => {
      if (!value) return true;
      return isValidJson(value);
    },
  })
  .test({
    name: "no-nested-values",
    test: (value) => {
      if (!value) return true;
      if (!isValidJson(value)) return true;

      const parsed = JSON.parse(value);
      if (typeof parsed !== "object" || Array.isArray(parsed)) {
        return false;
      }
      return Object.values(parsed).every((v) =>
        ["string", "number", "boolean"].includes(typeof v),
      );
    },
  });

const ipv4PortRegex =
  /^(\d{1,5}(-\d{1,5})?(:(\d{1,5}(-\d{1,5})?))?(\/(tcp|udp))?|(\d{1,3}\.){3}\d{1,3}:\d{1,5}(-\d{1,5})?:\d{1,5}(-\d{1,5})?(\/(tcp|udp))?)$/;
const ipv6PortRegex =
  /^(\[?[0-9a-fA-F:]+\]?:\d{1,5}(-\d{1,5})?:\d{1,5}(-\d{1,5})?(\/(tcp|udp))?)$/;

const portBindingsSchema = yup
  .string()
  .nullable()
  .transform((value) => value?.trim().replace(/\s*,\s*/g, ", "))
  .test({
    name: "is-valid-port-bindings",
    message: messages.portBindingsFormat.id,
    test: (value) =>
      !value ||
      value
        .split(", ")
        .every(
          (v) => ipv4PortRegex.test(v.trim()) || ipv6PortRegex.test(v.trim()),
        ),
  });

const bindingsSchema = yup
  .string()
  .nullable()
  .transform((value) => value?.trim().replace(/\s*,\s*/g, ", "))
  .test({
    name: "is-valid-bindings",
    message: messages.bindsInvalid.id,
    test: (value) =>
      !value ||
      value.split(", ").every((v) => {
        const parts = v.trim().split(":");
        return (
          (parts.length === 2 || parts.length === 3) &&
          parts.every((p) => p.trim() !== "")
        );
      }),
  });

const tmpfsOptSchema = yup
  .string()
  .nullable()
  .transform((value) => value?.trim())
  .test({
    name: "is-json-array-of-tmpfs",
    message: messages.tmpfsFormat.id,
    test: (value) => {
      if (!value) return true;
      let parsed: unknown;
      try {
        parsed = JSON.parse(value);
      } catch {
        return false;
      }
      if (
        !Array.isArray(parsed) ||
        !parsed.every((item) => typeof item === "string")
      )
        return false;
      return parsed.every((entry) =>
        /^\/[A-Za-z0-9/_-]+=[A-Za-z0-9,=:_-]+$/.test(entry),
      );
    },
  });

const storageOptSchema = yup
  .string()
  .nullable()
  .transform((value) => value?.trim())
  .test({
    name: "is-json-array-of-storage-opts",
    message: messages.storageFormat.id,
    test: (value) => {
      if (!value) return true;
      let parsed: unknown;
      try {
        parsed = JSON.parse(value);
      } catch {
        return false;
      }
      if (
        !Array.isArray(parsed) ||
        !parsed.every((item) => typeof item === "string")
      )
        return false;
      return parsed.every((entry) =>
        /^[A-Za-z0-9_.-]+=[A-Za-z0-9_.:-]+$/.test(entry),
      );
    },
  });

const extraHostsSchema = yup
  .array()
  .nullable()
  .of(
    yup
      .string()
      .required()
      .test({
        name: "is-valid-extra-host",
        message: messages.extraHostsFormat.id,
        test: (value) => {
          if (!value) return true;
          const regex =
            /^(?!-)[A-Za-z0-9-]{1,63}(?:\.[A-Za-z0-9-]{1,63})*:(?:\d{1,3}\.){3}\d{1,3}$/;
          return regex.test(value.trim());
        },
      }),
  );

const memorySchema = optionalNumberSchema
  .integer()
  .min(6 * 1024 * 1024)
  .nullable()
  .label(labels.memory.defaultMessage);

const memoryReservationSchema = optionalNumberSchema
  .integer()
  .min(0)
  .max(yup.ref("memory"))
  .nullable()
  .label(labels.memoryReservation.defaultMessage);

const memorySwapSchema = optionalNumberSchema
  .integer()
  .nullable()
  .test(
    "memorySwap-valid",
    messages.memorySwap.defaultMessage,
    function (value) {
      const memory = this.parent.memory;
      if (value == null || memory == null) return true;
      return value >= memory;
    },
  )
  .label(labels.memorySwap.defaultMessage);

const memorySwappinessSchema = optionalNumberSchema
  .integer()
  .min(0)
  .max(100)
  .nullable()
  .label(labels.memorySwappiness.defaultMessage);

const cpuPeriodSchema = optionalNumberSchema
  .integer()
  .min(1_000)
  .max(1_000_000)
  .nullable()
  .label(labels.cpuPeriod.defaultMessage);

const cpuQuotaSchema = optionalNumberSchema
  .integer()
  .min(1_000)
  .nullable()
  .label(labels.cpuQuota.defaultMessage)
  .test({
    name: "cpuQuotaPeriod",
    message: messages.cpuQuotaPeriod.id,
    test: function (cpuQuota) {
      const { cpuPeriod } = this.parent;
      const bothEmpty = cpuQuota == null && cpuPeriod == null;
      const bothSet = cpuQuota != null && cpuPeriod != null;
      return bothEmpty || bothSet;
    },
  });

const cpuRealtimePeriodSchema = optionalNumberSchema
  .integer()
  .min(1000)
  .nullable()
  .label(labels.cpuRealtimePeriod.defaultMessage);

const cpuRealtimeRuntimeSchema = optionalNumberSchema
  .integer()
  .max(yup.ref("cpuRealtimePeriod"))
  .nullable()
  .label(labels.cpuRealtimeRuntime.defaultMessage);

const capAddSchema = yup
  .array()
  .of(yup.string().required().oneOf(CapAddList))
  .nullable();
const capDropSchema = yup
  .array()
  .of(yup.string().required().oneOf(CapDropList))
  .nullable();

const networksSchema = yup
  .array(yup.object({ id: yup.string().required() }).required())
  .nullable();

const volumesSchema = yup
  .array(
    yup
      .object({
        id: yup.string(),
        target: yup.string().required(),
      })
      .required(),
  )
  .distinctOnProperty("target")
  .nullable();

const deviceMappingsSchema = yup
  .array(
    yup
      .object({
        pathInContainer: nullableTrimString.required(),
        pathOnHost: nullableTrimString.required(),
        cgroupPermissions: nullableTrimString.required(),
      })
      .required(),
  )
  .nullable();

const imageSchema = yup.object({
  reference: yup.string().required(),
  imageCredentialsId: yup.string().nullable(),
});

const requiredSystemModelsSchema = yup.array(
  yup.object({ id: yup.string().required() }),
);

export {
  yup,
  messages,
  fieldExplanations,
  handleSchema,
  baseImageFileSchema,
  baseImageVersionSchema,
  baseImageStartingVersionRequirementSchema,
  numberSchema,
  nullableTrimString,
  imageSchema,
  envSchema,
  portBindingsSchema,
  bindingsSchema,
  tmpfsOptSchema,
  storageOptSchema,
  extraHostsSchema,
  memorySchema,
  memoryReservationSchema,
  memorySwapSchema,
  memorySwappinessSchema,
  cpuPeriodSchema,
  cpuQuotaSchema,
  cpuRealtimePeriodSchema,
  cpuRealtimeRuntimeSchema,
  capAddSchema,
  capDropSchema,
  networksSchema,
  volumesSchema,
  deviceMappingsSchema,
  requiredSystemModelsSchema,
  optionsSchema,
};
