/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 SECO Mind Srl
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

import React from "react";
import { FormattedMessage } from "react-intl";

import Button from "@/components/Button";
import Form from "@/components/Form";
import Stack from "@/components/Stack";
import Icon from "@/components/Icon";

interface StringArrayFormInputProps {
  value: string[];
  onChange?: (value: string[]) => void;
  errors?: { message?: string }[];
  addButtonLabel?: React.ReactNode;
  mode?: "input" | "details";
}

const StringArrayFormInput: React.FC<StringArrayFormInputProps> = ({
  value,
  onChange,
  errors = [],
  addButtonLabel = (
    <FormattedMessage
      id="components.StringArrayFormInput.addButton"
      defaultMessage="Add Item"
    />
  ),
  mode = "input",
}) => {
  const handleAdd = () => {
    if (onChange) {
      onChange([...value, ""]);
    }
  };

  const handleDelete = (i: number) => {
    if (onChange) {
      onChange(value.filter((_, idx) => idx !== i));
    }
  };

  const handleChange = (i: number, newValue: string) => {
    if (onChange) {
      const updated = [...value];
      updated[i] = newValue;
      onChange(updated);
    }
  };

  //   TODO Make the details look better and easier to read
  if (mode === "details") {
    return (
      <Form.Control value={value.length > 0 ? value.join(", ") : ""} readOnly />
    );
  }

  return (
    <div className="p-3 border rounded">
      <Stack gap={3}>
        {value.map((item: string, i: number) => {
          const itemError = errors?.[i]?.message;
          return (
            <Stack direction="horizontal" gap={3} key={i}>
              <Stack>
                <Form.Control
                  value={item}
                  onChange={(e) => handleChange(i, e.target.value)}
                  isInvalid={!!itemError}
                />
                <Form.Control.Feedback type="invalid">
                  {itemError && <FormattedMessage id={itemError} />}
                </Form.Control.Feedback>
              </Stack>
              <Button
                className="mb-auto"
                variant="shadow-danger"
                onClick={() => handleDelete(i)}
              >
                <Icon className="text-danger" icon={"delete"} />
              </Button>
            </Stack>
          );
        })}
        <Button
          className="me-auto"
          variant="outline-primary"
          onClick={handleAdd}
        >
          {addButtonLabel}
        </Button>
      </Stack>
    </div>
  );
};

export default StringArrayFormInput;
