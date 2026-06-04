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

import { forwardRef } from "react";
import Form from "react-bootstrap/Form";
import type { DatePickerProps } from "react-datepicker";
import ReactDatePicker from "react-datepicker";
import "react-datepicker/dist/react-datepicker.css";

import "./DatePicker.scss";

type DatePickerInputProps = {
  value?: string;
  onClick?: React.MouseEventHandler<HTMLInputElement>;
} & Omit<React.ComponentPropsWithoutRef<"input">, "size">;

type CustomTimeInputProps = {
  date?: Date | null;
  value?: string;
  onChange: (time: string) => void;
};

const DatePickerInput = forwardRef<HTMLInputElement, DatePickerInputProps>(
  ({ value, onClick, ...inputProps }, ref) => {
    return (
      <Form.Control
        ref={ref}
        {...inputProps}
        onClick={onClick}
        value={value}
        readOnly
      />
    );
  },
);

const getCurrentTime = () => {
  const now = new Date();
  return now.toTimeString().slice(0, 5); // "HH:MM"
};

const openPicker = (input: HTMLInputElement | null) => {
  input?.showPicker?.();
};

const CustomTimeInput = forwardRef<HTMLInputElement, CustomTimeInputProps>(
  ({ value, onChange }, ref) => {
    const defaultTime = getCurrentTime();
    const timeValue = value || defaultTime;

    return (
      <Form.Control
        ref={ref}
        type="time"
        value={timeValue}
        onClick={(event) => openPicker(event.currentTarget as HTMLInputElement)}
        onChange={(e) => onChange(e.target.value)}
      />
    );
  },
);

const DatePicker = (props: DatePickerProps) => {
  // Use a div to wrap the date picker, since it will mount sibling components
  // next to itself.
  return (
    <div>
      <ReactDatePicker
        {...props}
        showTimeInput
        dateFormat="Pp"
        customInput={<DatePickerInput />}
        customTimeInput={<CustomTimeInput onChange={() => {}} />}
        popperPlacement="bottom-start"
        isClearable
      />
    </div>
  );
};

export default DatePicker;
