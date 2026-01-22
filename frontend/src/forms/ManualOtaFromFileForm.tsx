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

import { FormattedMessage } from "react-intl";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";

import Form from "@/components/Form";
import Button from "@/components/Button";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { manualOtaFromFileSchema } from "@/forms/validation";

type ManualOtaOperation = (input: {
  imageFile?: File;
  imageUrl?: string;
}) => void;

type FromFileFormProps = {
  className?: string;
  isLoading: boolean;
  onManualOTAImageSubmit: ManualOtaOperation;
};

const ManualOtaFromFileForm = ({
  className,
  isLoading,
  onManualOTAImageSubmit,
}: FromFileFormProps) => {
  const {
    formState: { errors },
    handleSubmit,
    register,
  } = useForm({
    mode: "onTouched",
    resolver: zodResolver(manualOtaFromFileSchema),
  });

  const onSubmit = handleSubmit((data) => {
    onManualOTAImageSubmit({ imageFile: data.baseImageFile[0] });
  });

  return (
    <form className={className} onSubmit={onSubmit}>
      <Form.Group controlId="baseImageFile">
        <Stack direction="vertical" gap={2} className="align-items-start">
          <Form.Label column sm={3} className="text-nowrap">
            <FormattedMessage
              id="components.ManualOtaFromFileForm.baseImageLabel"
              defaultMessage="Base image file"
            />
          </Form.Label>
          <Form.Control {...register("baseImageFile")} type="file" />
          <Form.Control.Feedback type="invalid">
            {errors.baseImageFile && (
              <FormattedMessage id={errors.baseImageFile?.message} />
            )}
          </Form.Control.Feedback>
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.ManualOtaFromFileForm.update"
              defaultMessage="Update"
            />
          </Button>
        </Stack>
      </Form.Group>
    </form>
  );
};

export default ManualOtaFromFileForm;
