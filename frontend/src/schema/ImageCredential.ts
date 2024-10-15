/*
  This file is part of Edgehog.

  Copyright 2024 SECO Mind Srl

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

import { defineMessages } from "react-intl";
import { object, setLocale, string } from "yup";

const messages = defineMessages({
  required: {
    id: "validation.required",
  },
  unique: {
    id: "validation.unique",
  },
  passwordShort: {
    id: "validation.password.short",
  },
  passwordStronger: {
    id: "validation.password.stronger",
  },
});

setLocale({
  string: {
    matches: () => ({ messageId: messages.passwordStronger.id }),
    min: () => ({ messageId: messages.passwordShort.id }),
  },
});

const commonImageCredentialSchema = object({
  label: string().required(),
  username: string().required(),
}).required();

export const imageCredentialResultSchema = object({
  id: string().required(),
}).required();

export const imageCredentialSchema = object()
  .concat(commonImageCredentialSchema)
  .concat(imageCredentialResultSchema)
  .required();

export const createImageCredentialSchema = object({
  password: string()
    .required()
    .matches(/^(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[!@#$%^_]).{8,12}$/, {
      message: messages.passwordStronger.id,
    }),
})
  .concat(commonImageCredentialSchema)
  .required();
