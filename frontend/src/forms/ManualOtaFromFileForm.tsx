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

import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";

import Button from "@/components/Button";
import Col from "@/components/Col";
import Form from "@/components/Form";
import { FormRowWithMargin as FormRow } from "@/components/FormRow";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import FormFeedback from "@/forms/FormFeedback";
import { manualOtaFromFileSchema } from "@/forms/validation";

type ManualOtaFromFileFormProps = {
  className?: string;
  isLoading: boolean;
  onManualOTAImageSubmit: (input: {
    imageFile?: File;
    imageUrl?: string;
  }) => void;
};

const ManualOtaFromFileForm = ({
  className,
  isLoading,
  onManualOTAImageSubmit,
}: ManualOtaFromFileFormProps) => {
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
      <FormRow
        id="baseImageFile"
        label={
          <FormattedMessage
            id="forms.ManualOtaFromFileForm.baseImageLabel"
            defaultMessage="Base image file"
          />
        }
      >
        <Form.Control {...register("baseImageFile")} type="file" />
        <FormFeedback feedback={errors.baseImageFile?.message} />
      </FormRow>

      <Row>
        <Col className="d-flex justify-content-end">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.ManualOtaFromFileForm.update"
              defaultMessage="Update"
            />
          </Button>
        </Col>
      </Row>
    </form>
  );
};

export default ManualOtaFromFileForm;
