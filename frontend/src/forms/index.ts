/*
  This file is part of Edgehog.

  Copyright 2021-2024 SECO Mind Srl

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
  portBindingsFormat: {
    id: "validation.portBindings.format",
    defaultMessage:
      "Port Bindings must be comma-separated values like '8080:80, 443:443'.",
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
});

yup.setLocale({
  mixed: {
    required: messages.required.id,
  },
  array: {
    min: messages.arrayMin.id,
  },
  number: {
    integer: (values) => ({ messageId: messages.numberInteger.id, values }),
    min: (values) => ({ messageId: messages.numberMin.id, values }),
    max: (values) => ({ messageId: messages.numberMax.id, values }),
    positive: (values) => ({ messageId: messages.numberPositive.id, values }),
  },
});

const systemModelHandleSchema = yup
  .string()
  .matches(/^[a-z][a-z\d-]*$/, messages.handleFormat.id);

const hardwareTypeHandleSchema = yup
  .string()
  .matches(/^[a-z][a-z\d-]*$/, messages.handleFormat.id);

const deviceGroupHandleSchema = yup
  .string()
  .matches(/^[a-z][a-z\d-]*$/, messages.handleFormat.id);

const baseImageCollectionHandleSchema = yup
  .string()
  .matches(/^[a-z][a-z\d-]*$/, messages.handleFormat.id);

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

const updateChannelHandleSchema = yup
  .string()
  .matches(/^[a-z][a-z\d-]*$/, messages.handleFormat.id);

const numberSchema = yup
  .number()
  .typeError((values) => ({ messageId: messages.number.id, values }));

const isValidJson = (value: string) => {
  try {
    JSON.parse(value);
    return true;
  } catch {
    return false;
  }
};

const envSchema = yup
  .string()
  .nullable()
  .transform((value) => value?.trim())
  .test({
    name: "is-json",
    message: messages.envInvalidJson.id,
    test: (value) => (value ? isValidJson(value) : true),
  });

const portBindingsSchema = yup
  .string()
  .nullable()
  .transform((value) => value?.trim().replace(/\s*,\s*/g, ", "))
  .test({
    name: "is-valid-port-bindings",
    message: messages.portBindingsFormat.id,
    test: (value) =>
      !value ||
      value.split(", ").every((v) => /^[0-9]+:[0-9]+$/.test(v.trim())),
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

      let parsed;
      try {
        parsed = JSON.parse(value);
      } catch {
        return false;
      }

      if (
        !Array.isArray(parsed) ||
        !parsed.every((item) => typeof item === "string")
      ) {
        return false;
      }

      const tmpfsRegex = /^\/[A-Za-z0-9/_-]+=[A-Za-z0-9,=:_-]+$/;

      for (const entry of parsed) {
        if (!tmpfsRegex.test(entry)) {
          return false;
        }
      }

      return true;
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
      ) {
        return false;
      }

      const keyValueRegex = /^[A-Za-z0-9_.-]+=[A-Za-z0-9_.:-]+$/;

      for (const entry of parsed) {
        if (!keyValueRegex.test(entry)) {
          return false;
        }
      }

      return true;
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

export {
  deviceGroupHandleSchema,
  systemModelHandleSchema,
  hardwareTypeHandleSchema,
  baseImageCollectionHandleSchema,
  baseImageFileSchema,
  baseImageVersionSchema,
  baseImageStartingVersionRequirementSchema,
  updateChannelHandleSchema,
  numberSchema,
  envSchema,
  portBindingsSchema,
  extraHostsSchema,
  messages,
  yup,
  tmpfsOptSchema,
  storageOptSchema,
};
