/*
  This file is part of Edgehog.

  Copyright 2021-2023 SECO Mind Srl

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
  messages,
  yup,
};
