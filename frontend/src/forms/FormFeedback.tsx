/*
 * This file is part of Edgehog.
 *
 * Copyright 2023, 2025 SECO Mind Srl
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

import type { ReactNode } from "react";
import { FormattedMessage } from "react-intl";
import Form from "@/components/Form";

type Props = {
  feedback:
    | undefined
    | string
    | {
        messageId: string;
        values: Record<string, ReactNode>;
      };
};

const FormFeedback = ({ feedback }: Props) => {
  if (feedback === undefined) {
    return null;
  }
  if (typeof feedback === "string") {
    return (
      <Form.Control.Feedback type="invalid">
        <FormattedMessage id={feedback} />
      </Form.Control.Feedback>
    );
  }

  const { messageId, values } = feedback;
  return (
    <Form.Control.Feedback type="invalid">
      <FormattedMessage id={messageId} values={values} />
    </Form.Control.Feedback>
  );
};

export default FormFeedback;
