/*
  This file is part of Edgehog.

  Copyright 2022 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import React, { useState } from "react";
import { FormattedMessage } from "react-intl";
import Form from "components/Form";
import Button from "components/Button";
import Spinner from "components/Spinner";
import Stack from "components/Stack";

type BaseImageFormProps = {
  className?: string;
  onSubmit: (e: File) => void;
  isLoading: boolean;
};

const BaseImageForm = ({
  className,
  isLoading,
  onSubmit,
}: BaseImageFormProps) => {
  const [file, setFile] = useState<File | null>(null);

  const handleFileSelection = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e?.target?.files && e.target.files.length > 0) {
      setFile(e.target.files[0]);
    } else {
      setFile(null);
    }
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();

    if (file) {
      onSubmit(file);
    }
  };

  return (
    <form className={className} onSubmit={handleSubmit}>
      <Form.Group controlId="updateFile">
        <Form.Label className="text-nowrap">
          <FormattedMessage
            id="components.BaseImageForm.baseImageLabel"
            defaultMessage="Base image file"
          />
        </Form.Label>
        <Stack direction="horizontal" gap={2}>
          <Form.Control type="file" onChange={handleFileSelection} />
          <Button variant="primary" type="submit" disabled={!file || isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.BaseImageForm.update"
              defaultMessage="Update"
            />
          </Button>
        </Stack>
      </Form.Group>
    </form>
  );
};

export default BaseImageForm;
export type { BaseImageFormProps };
