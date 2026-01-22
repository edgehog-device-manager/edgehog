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

import { defineMessages } from "react-intl";
import semverValid from "semver/functions/valid";
import semverValidRange from "semver/ranges/valid";
import z from "zod";

/* ----------------------------- Error Messages ----------------------------- */
const messages = defineMessages({
  required: {
    id: "validation.required",
    defaultMessage: "Required.",
  },
  unique: {
    id: "validation.unique",
    defaultMessage: "Duplicate value.",
  },
  invalidJson: {
    id: "validation.invalidJson",
    defaultMessage: "Must be a valid JSON string.",
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
    defaultMessage: "Must be a number.",
  },
  numberPositive: {
    id: "validation.number.positive",
    defaultMessage: "Must be a positive number.",
  },
  numberInt: {
    id: "validation.number.int",
    defaultMessage: "Decimals are not allowed.",
  },
  numberMin: {
    id: "validation.number.min",
    defaultMessage: "Must be greater than or equal to {min}.",
  },
  numberMax: {
    id: "validation.number.max",
    defaultMessage: "Must be less than or equal to {max}.",
  },
  invalidIsNested: {
    id: "validation.json.invalidIsNested",
    defaultMessage: "Values cannot be nested.",
  },
  expectedObject: {
    id: "validation.json.expectedObject",
    defaultMessage: "Expected an object with key-value pairs",
  },
  portBindingsFormat: {
    id: "validation.portBindings.format",
    defaultMessage:
      "Invalid port binding format. Use [host_port:]container_port[/protocol].",
  },
  bindsInvalid: {
    id: "validation.binds.format",
    defaultMessage:
      "Invalid bind mount format. Use '/host/path:/container/path[:ro|rw]'.",
  },
  extraHostsFormat: {
    id: "validation.extraHosts.format",
    defaultMessage:
      "Invalid extra host format. Use 'hostname:IP' or 'hostname:host-gateway'.",
  },
  tmpfsFormat: {
    id: "validation.tmpfs.format",
    defaultMessage:
      "Invalid tmpfs mount format. Use '/container/path=option1,option2'.",
  },
  storageFormat: {
    id: "validation.storage.format",
    defaultMessage: "Invalid storage option format. Use 'key=value'.",
  },
  memorySwap: {
    id: "validation.memorySwapInvalid",
    defaultMessage: "Memory Swap must be greater than/equal to Memory.",
  },
  memoryReservation: {
    id: "validation.memoryReservationInvalid",
    defaultMessage:
      "Memory Reservation must be set lower than Memory in order to take precedence.",
  },
  cpuQuotaPeriod: {
    id: "validation.cpuQuotaPeriod.format",
    defaultMessage:
      "CPU Period and CPU Quota must be either both set or both unset",
  },
  volumeTarget: {
    id: "validation.volumeTarget.duplicate",
    defaultMessage: "Duplicate target value.",
  },
});

/* ----------------------------- Constants ----------------------------- */
const CapDropList = [
  "CAP_AUDIT_WRITE",
  "CAP_CHOWN",
  "CAP_DAC_OVERRIDE",
  "CAP_FOWNER",
  "CAP_FSETID",
  "CAP_KILL",
  "CAP_MKNOD",
  "CAP_NET_BIND_SERVICE",
  "CAP_NET_RAW",
  "CAP_SETFCAP",
  "CAP_SETGID",
  "CAP_SETPCAP",
  "CAP_SETUID",
  "CAP_SYS_CHROOT",
] as const;

const CapAddList = [
  "CAP_AUDIT_CONTROL",
  "CAP_BLOCK_SUSPEND",
  "CAP_DAC_READ_SEARCH",
  "CAP_IPC_LOCK",
  "CAP_IPC_OWNER",
  "CAP_LEASE",
  "CAP_LINUX_IMMUTABLE",
  "CAP_MAC_ADMIN",
  "CAP_MAC_OVERRIDE",
  "CAP_NET_ADMIN",
  "CAP_NET_BROADCAST",
  "CAP_SYS_ADMIN",
  "CAP_SYS_BOOT",
  "CAP_SYS_MODULE",
  "CAP_SYS_NICE",
  "CAP_SYS_PACCT",
  "CAP_SYS_PTRACE",
  "CAP_SYS_RAWIO",
  "CAP_SYS_RESOURCE",
  "CAP_SYS_TIME",
  "CAP_SYS_TTY_CONFIG",
  "CAP_SYSLOG",
  "CAP_WAKE_ALARM",
] as const;

/* ----------------------------- Overrides ----------------------------- */
z.config({
  customError: (issue) => {
    if (
      issue.code === "invalid_type" &&
      (issue.input === undefined || issue.input === null)
    ) {
      return messages.required.id;
    }

    if (issue.code === "invalid_type" && issue.expected === "number") {
      return messages.number.id;
    }

    if (issue.code === "invalid_type" && issue.expected === "int") {
      return messages.numberInt.id;
    }

    if (
      issue.code === "too_small" &&
      typeof issue.input === "string" &&
      issue.minimum === 1
    ) {
      return messages.required.id;
    }

    if (
      issue.code === "too_small" &&
      typeof issue.input === "number" &&
      issue.minimum === 0 &&
      issue.inclusive === false
    ) {
      return messages.numberPositive.id;
    }

    if (issue.code === "too_small") {
      return JSON.stringify({
        messageId: messages.numberMin.id,
        values: { min: issue.minimum },
      });
    }
    if (issue.code === "too_big") {
      return JSON.stringify({
        messageId: messages.numberMax.id,
        values: { max: issue.maximum },
      });
    }
  },
});

/* ----------------------------- Helpers ----------------------------- */
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

const isNotNested = (value: Array<KeyValueMaybeNested>): boolean => {
  return value.every(
    ({ value: v }) =>
      v === null || ["number", "boolean", "string"].includes(typeof v),
  );
};
const requiredNumber = z.number({
  error: (iss) =>
    iss.input === undefined ? messages.required.id : messages.number.id,
});

/* ----------------------------- Schemas ----------------------------- */

const handleSchema = z
  .string()
  .regex(/^[a-z][a-z\d-]*$/, messages.handleFormat.id);

const baseImageFileSchema = z
  .instanceof(FileList)
  .refine((files) => files.length > 0, {
    message: messages.baseImageFileSchema.id,
  });

const baseImageVersionSchema = z
  .string()
  .refine((value) => semverValid(value) !== null, {
    message: messages.baseImageVersionFormat.id,
  });

const baseImageStartingVersionRequirementSchema = z
  .string()
  .refine((value) => semverValidRange(value) !== null, {
    message: messages.baseImageStartingVersionRequirementFormat.id,
  });

const imageSchema = z.object({
  reference: z.string().min(1),
  imageCredentialsId: z.string().optional(),
});

const nullableTrimString = z
  .string()
  .trim()
  .transform((val) => val || undefined);

const targetGroup = z.object({
  channel: z
    .object({
      name: z.string(),
    })
    .nullable(),
  name: z.string(),
  id: z.string(),
});
type TargetGroup = z.infer<typeof targetGroup>;

const targetGroupExtended = targetGroup.extend({
  channel: z
    .object({
      id: z.string(),
      name: z.string(),
    })
    .nullable(),
});
type TargetGroupExtended = z.infer<typeof targetGroupExtended>;

const partNumber = z.object({
  value: z.string().min(1),
});
type PartNumber = z.infer<typeof partNumber>;

const partNumbersSchema = z
  .array(partNumber)
  .min(1)
  .superRefine((partNumbers, ctx) => {
    const seen = new Map<string, number[]>();

    partNumbers.forEach((pn, index) => {
      const value = pn.value;

      if (!seen.has(value)) {
        seen.set(value, [index]);
      } else {
        seen.get(value)!.push(index);
      }
    });

    seen.forEach((indexes) => {
      if (indexes.length > 1) {
        indexes.forEach((i) => {
          ctx.addIssue({
            code: "custom",
            message: messages.unique.id,
            path: [i, "value"],
          });
        });
      }
    });
  });

const optionsSchema = z
  .string()
  .trim()
  .superRefine((value, ctx) => {
    if (!value) return;

    if (!isValidJson(value)) {
      ctx.addIssue({
        code: "custom",
        message: messages.invalidJson.id,
      });
      return;
    }

    const parsed = JSON.parse(value);

    if (
      typeof parsed !== "object" ||
      parsed === null ||
      Array.isArray(parsed)
    ) {
      ctx.addIssue({
        code: "custom",
        message: messages.expectedObject.id,
      });
      return;
    }

    const pairs = Object.entries(parsed).map(([key, value]) => ({
      key,
      value,
    }));

    if (!isNotNested(pairs)) {
      ctx.addIssue({
        code: "custom",
        message: messages.invalidIsNested.id,
      });
    }
  });

const applicationSchema = z.object({
  name: z.string().min(1),
  description: z.string().optional(),
});
type ApplicationFormData = z.infer<typeof applicationSchema>;

const networkSchema = z.object({
  label: z.string().min(1),
  driver: z.string().optional(),
  options: optionsSchema.optional(),
  internal: z.boolean().optional(),
  enableIpv6: z.boolean().optional(),
});
type NetworkFormData = z.infer<typeof networkSchema>;

const volumeSchema = z.object({
  label: z.string().min(1),
  driver: z.string().optional(),
  options: optionsSchema.optional(),
});
type VolumeFormData = z.infer<typeof volumeSchema>;

const channelSchema = z.object({
  name: z.string().min(1),
  handle: handleSchema.min(1),
  targetGroups: z.array(targetGroup).nonempty(messages.required.id),
});

const updateChannelSchema = channelSchema.extend({
  id: z.string(),
  targetGroups: z.array(targetGroupExtended).nonempty(messages.required.id),
});

type ChannelFormData = z.infer<typeof channelSchema>;
type ChannelUpdateFormData = z.infer<typeof updateChannelSchema>;

const deviceGroupSchema = z.object({
  name: z.string().min(1),
  handle: handleSchema.min(1),
  selector: z.string().min(1),
});
type DeviceGroupFormData = z.infer<typeof deviceGroupSchema>;

const imageCredentialSchema = z.object({
  label: z.string().min(1),
  username: z.string().min(1),
  password: z.string().min(1),
});
type ImageCredentialFormData = z.infer<typeof imageCredentialSchema>;

const imageCredentialUpdateSchema = z.object({
  id: z.string().min(1),
  label: z.string().min(1),
  username: z.string().min(1),
});
type ImageCredentialUpdateFormData = z.infer<
  typeof imageCredentialUpdateSchema
>;

const hardwareTypeSchema = z.object({
  name: z.string().min(1),
  handle: handleSchema.min(1),
  partNumbers: partNumbersSchema,
});
type HardwareTypeFormData = z.infer<typeof hardwareTypeSchema>;

const systemModelSchema = z.object({
  name: z.string().min(1),
  handle: handleSchema.min(1),
  description: z.string(),
  hardwareType: z.object({
    id: z.string().min(1),
    name: z.string().min(1),
  }),
  partNumbers: partNumbersSchema,
  pictureFile: z.instanceof(FileList).nullable(),
});
type SystemModelFormData = z.infer<typeof systemModelSchema>;

const systemModelUpdateSchema = systemModelSchema.extend({
  hardwareType: z.string().optional(),
});
type SystemModelUpdateFormData = z.infer<typeof systemModelUpdateSchema>;

const baseImageSchema = z.object({
  baseImageCollection: z.string().min(1),
  file: baseImageFileSchema.optional(),
  version: baseImageVersionSchema.min(1),
  startingVersionRequirement: baseImageStartingVersionRequirementSchema,
  releaseDisplayName: z.string(),
  description: z.string(),
});
type BaseImageFormData = z.infer<typeof baseImageSchema>;

const baseImageUpdateSchema = baseImageSchema.omit({
  baseImageCollection: true,
  file: true,
  version: true,
});
type BaseImageUpdateFormData = z.infer<typeof baseImageUpdateSchema>;

const baseImageCollectionSchema = z.object({
  name: z.string().min(1),
  handle: handleSchema.min(1),
  systemModel: z.object({
    id: z.string().min(1),
    name: z.string().min(1),
  }),
});
type BaseImageCollectionFormData = z.infer<typeof baseImageCollectionSchema>;

const baseImageCollectionUpdateSchema = baseImageCollectionSchema.extend({
  systemModel: z.string(),
});
type BaseImageCollectionUpdateFormData = z.infer<
  typeof baseImageCollectionUpdateSchema
>;

const baseImageCollectionForBaseImageSelectSchema = baseImageCollectionSchema
  .pick({ name: true })
  .safeExtend({ id: z.string().min(1) });

const baseImageSelectSchema = baseImageSchema
  .pick({ version: true })
  .safeExtend({
    id: z.string().min(1),
    name: z.string(),
    url: z.string().min(1),
  });

const manualOtaFromCollectionSchema = z.object({
  baseImageCollection: baseImageCollectionForBaseImageSelectSchema,
  baseImage: baseImageSelectSchema,
});

type ManualOtaFromCollectionData = z.infer<
  typeof manualOtaFromCollectionSchema
>;

const manualOtaFromFileSchema = z.object({
  baseImageFile: baseImageFileSchema,
});

type ManualOtaFromFileData = z.infer<typeof manualOtaFromFileSchema>;

/* ----------------------------- Campaigns Schemas ----------------------------- */

const deploymentCampaignSchema = z
  .object({
    name: z.string().min(1),
    application: z.object({
      id: z.string().min(1),
      name: z.string().min(1),
    }),
    release: z.object({
      id: z.string().min(1),
      version: z.string().min(1),
    }),
    targetRelease: z
      .object({
        id: z.string().min(1),
        version: z.string().min(1),
      })
      .optional(),
    channel: z.object({
      id: z.string().min(1),
      name: z.string().min(1),
    }),
    operationType: z.enum(["Deploy", "Start", "Stop", "Upgrade", "Delete"]),
    maxInProgressOperations: requiredNumber.int().positive(),
    maxFailurePercentage: requiredNumber.min(0).max(100),
    requestTimeoutSeconds: requiredNumber.int().positive().min(30),
    requestRetries: requiredNumber.int().min(0),
  })
  .superRefine((data, ctx) => {
    if (data.operationType === "Upgrade" && !data.targetRelease) {
      ctx.addIssue({
        code: "custom",
        message: messages.required.id,
        path: ["targetRelease.id"],
      });
    }
  });

type DeploymentCampaignFormData = z.infer<typeof deploymentCampaignSchema>;

const updateCampaignSchema = z.object({
  name: z.string().min(1),
  baseImageCollection: baseImageCollectionForBaseImageSelectSchema,
  baseImage: baseImageSelectSchema.partial({ url: true }),
  channel: z.object({
    id: z.string().min(1),
    name: z.string().min(1),
  }),
  operationType: z.enum(["FirmwareUpgrade"]),
  maxInProgressOperations: requiredNumber.int().positive(),
  maxFailurePercentage: requiredNumber.min(0).max(100),
  requestTimeoutSeconds: requiredNumber.int().positive().min(30),
  requestRetries: requiredNumber.int().min(0),
  forceDowngrade: z.boolean(),
});

type UpdateCampaignFormData = z.infer<typeof updateCampaignSchema>;

/* ----------------------------- Container Schemas ----------------------------- */

const ipv4PortRegex =
  /^(\d{1,5}(-\d{1,5})?(:(\d{1,5}(-\d{1,5})?))?(\/(tcp|udp))?|(\d{1,3}\.){3}\d{1,3}:\d{1,5}(-\d{1,5})?:\d{1,5}(-\d{1,5})?(\/(tcp|udp))?)$/;

const ipv6PortRegex =
  /^(\[?[0-9a-fA-F:]+\]?:\d{1,5}(-\d{1,5})?:\d{1,5}(-\d{1,5})?(\/(tcp|udp))?)$/;

const portBindingsSchema = z.array(
  z
    .string()
    .min(1)
    .refine(
      (value) =>
        ipv4PortRegex.test(value.trim()) || ipv6PortRegex.test(value.trim()),
      { message: messages.portBindingsFormat.id },
    ),
);

const bindingsSchema = z.array(
  z
    .string()
    .min(1)
    .refine(
      (value) => {
        if (value.includes(",")) return false;
        const parts = value.trim().split(":");
        return (
          (parts.length === 2 || parts.length === 3) &&
          parts.every((p) => p.trim() !== "")
        );
      },
      { message: messages.bindsInvalid.id },
    ),
);

const tmpfsOptSchema = z.array(
  z
    .string()
    .min(1)
    .refine(
      (value) => /^\/[A-Za-z0-9/_-]+=[A-Za-z0-9,=:_-]+$/.test(value.trim()),
      { message: messages.tmpfsFormat.id },
    ),
);

const storageOptSchema = z.array(
  z
    .string()
    .min(1)
    .refine(
      (value) => /^[A-Za-z0-9_.-]+=[A-Za-z0-9_.:-]+$/.test(value.trim()),
      { message: messages.storageFormat.id },
    ),
);

const extraHostsSchema = z.array(
  z
    .string()
    .min(1)
    .refine(
      (value) => {
        const colonIndex = value.indexOf(":");
        if (colonIndex === -1) return false;

        const hostnamePart = value.slice(0, colonIndex).trim();
        const ipPart = value.slice(colonIndex + 1).trim();

        if (!hostnamePart || !ipPart) return false;

        const hostnameRegex = /^[a-zA-Z0-9.-]+$/;
        if (!hostnameRegex.test(hostnamePart)) return false;

        const cleanIp =
          ipPart.startsWith("[") && ipPart.endsWith("]")
            ? ipPart.slice(1, -1)
            : ipPart;

        const isIpv4 = z.ipv4().safeParse(cleanIp).success;
        const isIpv6 = z.ipv6().safeParse(cleanIp).success;

        return isIpv4 || isIpv6;
      },
      {
        message: messages.extraHostsFormat.id,
      },
    ),
);

const memorySchema = z
  .number()
  .int()
  .min(6 * 1024 * 1024);

const memoryReservationSchema = z.number(messages.number.id).int().min(0);

const memorySwapSchema = z.number(messages.number.id).int();

const memorySwappinessSchema = z
  .number(messages.number.id)
  .int()
  .min(0)
  .max(100);

const cpuPeriodSchema = z
  .number(messages.number.id)
  .int()
  .min(1_000)
  .max(1_000_000);

const cpuQuotaSchema = z.number(messages.number.id).int().min(1_000);

const cpuRealtimePeriodSchema = z.number(messages.number.id).int().min(1000);

const cpuRealtimeRuntimeSchema = z.number(messages.number.id).int();

const capAddSchema = z.array(z.enum(CapAddList));

const capDropSchema = z.array(z.enum(CapDropList));

const networksSchema = z.array(z.object({ id: z.string().min(1) }));

const volumesSchema = z
  .array(
    z.object({
      id: z.string(),
      target: z.string().min(1),
    }),
  )
  .superRefine((volumes, ctx) => {
    if (!volumes) return;

    const seen = new Set<string>();

    volumes.forEach((volume, index) => {
      if (seen.has(volume.target)) {
        ctx.addIssue({
          path: [index, "target"],
          code: "custom",
          message: messages.volumeTarget.id,
        });
      } else {
        seen.add(volume.target);
      }
    });
  });

const envSchema = z
  .any()
  .nullable()
  .transform((value): KeyValueMaybeNested[] | null => {
    if (isValidJson(value)) {
      const parsed = JSON.parse(value);

      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        return Object.entries(parsed).map(
          ([key, val]) =>
            ({
              key,
              value: val,
            }) as KeyValueMaybeNested,
        );
      }
    }

    return value;
  })
  .superRefine((value, ctx) => {
    if (!value) return;

    if (Array.isArray(value)) {
      if (!isNotNested(Object.values(value))) {
        ctx.addIssue({
          code: "custom",
          message: messages.invalidIsNested.id,
        });
      }
      return;
    }

    if (!isValidJson(value)) {
      ctx.addIssue({
        code: "custom",
        message: messages.invalidJson.id,
      });
      return;
    }

    const parsed = JSON.parse(value);

    if (
      typeof parsed !== "object" ||
      parsed === null ||
      Array.isArray(parsed)
    ) {
      ctx.addIssue({
        code: "custom",
        message: messages.expectedObject.id,
      });
    }
  });

const deviceMappingsSchema = z.array(
  z.object({
    pathInContainer: z.string().trim().min(1),
    pathOnHost: z.string().trim().min(1),
    cgroupPermissions: z.string().trim().min(1),
  }),
);

const containerSchema = z.object({
  image: imageSchema.optional(),
  hostname: nullableTrimString.optional(),
  networkMode: nullableTrimString.optional(),
  networks: networksSchema.optional(),
  extraHosts: extraHostsSchema.optional(),
  portBindings: portBindingsSchema.optional(),
  binds: bindingsSchema.optional(),
  volumes: volumesSchema.optional(),
  volumeDriver: nullableTrimString.optional(),
  storageOpt: storageOptSchema.optional(),
  tmpfs: tmpfsOptSchema.optional(),
  readOnlyRootfs: z.boolean().optional(),
  memory: memorySchema.optional(),
  memoryReservation: memoryReservationSchema.optional(),
  memorySwap: memorySwapSchema.optional(),
  memorySwappiness: memorySwappinessSchema.optional(),
  cpuPeriod: cpuPeriodSchema.optional(),
  cpuQuota: cpuQuotaSchema.optional(),
  cpuRealtimePeriod: cpuRealtimePeriodSchema.optional(),
  cpuRealtimeRuntime: cpuRealtimeRuntimeSchema.optional(),
  privileged: z.boolean().optional(),
  capAdd: capAddSchema.optional(),
  capDrop: capDropSchema.optional(),
  restartPolicy: nullableTrimString.optional(),
  env: envSchema.optional(),
  deviceMappings: deviceMappingsSchema.optional(),
});

type ContainerInputData = z.infer<typeof containerSchema>;

const requiredSystemModelsSchema = z.array(z.object({ id: z.string().min(1) }));

const releaseSchema = z
  .object({
    version: z.string().min(1),
    requiredSystemModels: requiredSystemModelsSchema.optional(),
    containers: z.array(containerSchema).optional(),
  })
  .superRefine((data, ctx) => {
    data.containers?.forEach((container, index) => {
      const cpuPeriod = container.cpuPeriod;
      const cpuQuota = container.cpuQuota;

      const cpuBothEmpty = cpuPeriod == null && cpuQuota == null;
      const cpuBothSet = cpuPeriod != null && cpuQuota != null;

      if (!cpuBothEmpty && !cpuBothSet) {
        ctx.addIssue({
          path: [
            "containers",
            index,
            cpuPeriod == null ? "cpuPeriod" : "cpuQuota",
          ],
          message: messages.cpuQuotaPeriod.id,
          code: "custom",
        });
      }

      const memory = container.memory;
      const memoryReservation = container.memoryReservation;
      const memorySwap = container.memorySwap;

      if (
        memory != null &&
        memoryReservation != null &&
        memoryReservation > memory
      ) {
        ctx.addIssue({
          path: ["containers", index, "memoryReservation"],
          message: messages.memoryReservation.id,
          code: "custom",
        });
      }

      if (memory != null && memorySwap != null && memorySwap < memory) {
        ctx.addIssue({
          path: ["containers", index, "memorySwap"],
          message: messages.memorySwap.id,
          code: "custom",
        });
      }
    });
  });

type ReleaseFormData = z.infer<typeof releaseSchema>;

/* ----------------------------- Exports ----------------------------- */

export type {
  ApplicationFormData,
  NetworkFormData,
  VolumeFormData,
  ChannelFormData,
  DeviceGroupFormData,
  ImageCredentialFormData,
  ChannelUpdateFormData,
  HardwareTypeFormData,
  SystemModelFormData,
  SystemModelUpdateFormData,
  BaseImageFormData,
  BaseImageUpdateFormData,
  BaseImageCollectionFormData,
  BaseImageCollectionUpdateFormData,
  ManualOtaFromCollectionData,
  ManualOtaFromFileData,
  ImageCredentialUpdateFormData,
  DeploymentCampaignFormData,
  UpdateCampaignFormData,
  ReleaseFormData,
  ContainerInputData,
  TargetGroup,
  TargetGroupExtended,
  PartNumber,
};

export {
  applicationSchema,
  networkSchema,
  volumeSchema,
  channelSchema,
  deviceGroupSchema,
  imageCredentialSchema,
  updateChannelSchema,
  targetGroupExtended,
  hardwareTypeSchema,
  systemModelSchema,
  systemModelUpdateSchema,
  baseImageSchema,
  baseImageUpdateSchema,
  baseImageCollectionSchema,
  baseImageCollectionUpdateSchema,
  baseImageFileSchema,
  manualOtaFromCollectionSchema,
  manualOtaFromFileSchema,
  imageCredentialUpdateSchema,
  deploymentCampaignSchema,
  updateCampaignSchema,
  releaseSchema,
  CapAddList,
  CapDropList,
};
