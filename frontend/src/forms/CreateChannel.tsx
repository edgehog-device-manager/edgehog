/*
  This file is part of Edgehog.

  Copyright 2023-2025 SECO Mind Srl

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

import React, { useMemo, useCallback } from "react";
import { useForm, Controller } from "react-hook-form";
import { useIntl, FormattedMessage } from "react-intl";
import { yupResolver } from "@hookform/resolvers/yup";

import type { CreateChannel_OptionsFragment$key } from "api/__generated__/CreateChannel_OptionsFragment.graphql";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import MultiSelect from "components/MultiSelect";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { channelHandleSchema, yup, messages } from "forms";
import { graphql, useFragment } from "react-relay/hooks";

const CREATE_UPDATE_CHANNEL_OPTIONS_FRAGMENT = graphql`
  fragment CreateChannel_OptionsFragment on RootQueryType {
    deviceGroups {
      edges {
        node {
          id
          name
          channel {
            name
          }
        }
      }
    }
  }
`;

const FormRow = ({
  id,
  label,
  children,
}: {
  id: string;
  label: React.ReactNode;
  children: React.ReactNode;
}) => (
  <Form.Group as={Row} controlId={id}>
    <Form.Label column sm={3}>
      {label}
    </Form.Label>
    <Col sm={9}>{children}</Col>
  </Form.Group>
);

// react-hook-form returns targetGroups validation error as Array<Record<string, FieldError>> type
// ignoring eventual minimum length validation error type.
// TargetGroupsErrors handles errors as unknown and uses type guards to render type-safe error message.
// TODO: update RHF
const TargetGroupsErrors = ({ errors }: { errors: unknown }) => {
  if (errors == null) {
    return null;
  }
  if (typeof errors === "object" && !Array.isArray(errors)) {
    if (
      "message" in errors &&
      typeof (errors as Record<"message", unknown>).message === "string"
    ) {
      const message = (errors as Record<"message", string>).message;
      return <FormattedMessage id={message} />;
    }
  }
  return null;
};

type TargetGroup = {
  readonly id: string;
  readonly name: string;
  readonly channel: {
    readonly name: string;
  } | null;
};

const getTargetGroupValue = (targetGroup: TargetGroup) => targetGroup.id;
const isTargetGroupUsedByOtherChannel = (targetGroup: TargetGroup) =>
  targetGroup.channel !== null;

type ChannelData = {
  name: string;
  handle: string;
  targetGroupIds: string[];
};

type FormData = {
  name: string;
  handle: string;
  targetGroups: TargetGroup[];
};

const channelSchema = yup
  .object({
    name: yup.string().required(),
    handle: channelHandleSchema.required(),
    targetGroups: yup.array().ensure().min(1, messages.required.id),
  })
  .required();

const initialData: FormData = {
  name: "",
  handle: "",
  targetGroups: [],
};

const transformOutputData = ({
  targetGroups,
  ...rest
}: FormData): ChannelData => ({
  ...rest,
  targetGroupIds: targetGroups.map((targetGroup) => targetGroup.id),
});

type Props = {
  queryRef: CreateChannel_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: ChannelData) => void;
};

const CreateChannel = ({ queryRef, isLoading = false, onSubmit }: Props) => {
  const { deviceGroups: targetGroups } = useFragment(
    CREATE_UPDATE_CHANNEL_OPTIONS_FRAGMENT,
    queryRef,
  );
  const {
    register,
    handleSubmit,
    formState: { errors },
    control,
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(channelSchema),
  });

  const intl = useIntl();
  const getTargetGroupLabel = useCallback(
    (targetGroup: TargetGroup) => {
      if (targetGroup.channel === null) {
        return targetGroup.name;
      }
      return intl.formatMessage(
        {
          id: "forms.CreateChannel.targetGroupWithChannelLabel",
          defaultMessage: "{targetGroupName} (used for {channelName})",
          description:
            "Target group label of select option with optional channel name it used for.",
        },
        {
          targetGroupName: targetGroup.name,
          channelName: targetGroup.channel.name,
        },
      );
    },
    [intl],
  );

  const targetGroupOptions = useMemo(() => {
    // move disabled options to the end
    return [...(targetGroups?.edges?.map((edge) => edge.node) || [])].sort(
      (group1, group2) => {
        const group1Disabled = isTargetGroupUsedByOtherChannel(group1);
        const group2Disabled = isTargetGroupUsedByOtherChannel(group2);

        if (group1Disabled === group2Disabled) {
          return 0;
        }
        if (group1Disabled) {
          return 1;
        }
        return -1;
      },
    );
  }, [targetGroups]);

  const onFormSubmit = (data: FormData) => onSubmit(transformOutputData(data));

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="create-channel-form-name"
          label={
            <FormattedMessage
              id="forms.CreateChannel.nameLabel"
              defaultMessage="Name"
            />
          }
        >
          <Form.Control {...register("name")} isInvalid={!!errors.name} />
          <Form.Control.Feedback type="invalid">
            {errors.name?.message && (
              <FormattedMessage id={errors.name?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <FormRow
          id="create-channel-form-handle"
          label={
            <FormattedMessage
              id="forms.CreateChannel.handleLabel"
              defaultMessage="Handle"
            />
          }
        >
          <Form.Control {...register("handle")} isInvalid={!!errors.handle} />
          <Form.Control.Feedback type="invalid">
            {errors.handle?.message && (
              <FormattedMessage id={errors.handle?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <FormRow
          id="create-channel-form-target-groups"
          label={
            <FormattedMessage
              id="forms.CreateChannel.targetGroupsLabel"
              defaultMessage="Target Groups"
            />
          }
        >
          <Controller
            name="targetGroups"
            control={control}
            render={({
              field: { value, onChange, onBlur },
              fieldState: { invalid },
            }) => (
              <MultiSelect
                invalid={invalid}
                value={value}
                onChange={onChange}
                onBlur={onBlur}
                options={targetGroupOptions}
                getOptionLabel={getTargetGroupLabel}
                getOptionValue={getTargetGroupValue}
                isOptionDisabled={isTargetGroupUsedByOtherChannel}
              />
            )}
          />
          <Form.Control.Feedback type="invalid">
            {errors.targetGroups && (
              <TargetGroupsErrors errors={errors.targetGroups} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.CreateChannel.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { ChannelData };

export default CreateChannel;
