/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { ReactNode } from "react";
import { Row, Col, Form } from "react-bootstrap";

type FormRowVariant = "form-group" | "simple-row";

export interface FormRowProps {
  id?: string;
  label?: ReactNode;
  children: ReactNode;
  layout?: FormRowVariant;
  className?: string;
  labelClassName?: string;
  labelCol?: number;
  valueCol?: number;
}

export const FormRowWithMargin = (props: FormRowProps) => (
  <FormRow {...props} className="mb-4" />
);

export const SimpleFormRow = (props: FormRowProps) => (
  <FormRow {...props} layout="simple-row" />
);

export const FormRow = ({
  id,
  label,
  children,
  layout = "form-group",
  className,
  labelClassName,
  labelCol = 3,
  valueCol = 9,
}: FormRowProps) => {
  if (layout === "simple-row") {
    return (
      <Row className={className}>
        <Col sm={labelCol} lg>
          {label}
        </Col>
        <Col sm={valueCol} lg>
          {children}
        </Col>
      </Row>
    );
  }

  return (
    <Form.Group as={Row} controlId={id} className={className}>
      <Form.Label column sm={labelCol} className={labelClassName}>
        {label}
      </Form.Label>
      <Col sm={valueCol}>{children}</Col>
    </Form.Group>
  );
};
