/*
  This file is part of Edgehog.

  Copyright 2023-2024 SECO Mind Srl

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

import React, { useCallback, useMemo, useEffect } from "react";
import { useForm, Controller } from "react-hook-form";
import { useIntl, FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import MultiSelect from "components/MultiSelect";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { updateChannelHandleSchema, yup, messages } from "forms";

import type {
  UpdateUpdateChannel_UpdateChannelFragment$key,
  UpdateUpdateChannel_UpdateChannelFragment$data,
} from "api/__generated__/UpdateUpdateChannel_UpdateChannelFragment.graphql";
import type {
  UpdateUpdateChannel_OptionsFragment$key,
  UpdateUpdateChannel_OptionsFragment$data,
} from "api/__generated__/UpdateUpdateChannel_OptionsFragment.graphql";

const UPDATE_UPDATE_CHANNEL_FRAGMENT = graphql`
  fragment UpdateUpdateChannel_UpdateChannelFragment on UpdateChannel {
    id
    name
    handle
    targetGroups {
      id
      name
      updateChannel {
        id
        name
      }
    }
  }
`;

const UPDATE_UPDATE_CHANNEL_OPTIONS_FRAGMENT = graphql`
  fragment UpdateUpdateChannel_OptionsFragment on RootQueryType {
    deviceGroups {
      id
      name
      updateChannel {
        id
        name
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

type UpdateChannel = Omit<
  UpdateUpdateChannel_UpdateChannelFragment$data,
  " $fragmentType"
>;
type TargetGroup =
  UpdateUpdateChannel_OptionsFragment$data["deviceGroups"][number];

const getTargetGroupValue = (targetGroup: TargetGroup) => targetGroup.id;

type UpdateChannelData = {
  name: string;
  handle: string;
  targetGroupIds: string[];
};

const updateChannelSchema = yup
  .object({
    name: yup.string().required(),
    handle: updateChannelHandleSchema.required(),
    targetGroups: yup.array().ensure().min(1, messages.required.id),
  })
  .required();

const transformOutputData = ({
  id: _id,
  targetGroups,
  ...rest
}: UpdateChannel): UpdateChannelData => ({
  ...rest,
  targetGroupIds: targetGroups.map((targetGroup) => targetGroup.id),
});

type Props = {
  updateChannelRef: UpdateUpdateChannel_UpdateChannelFragment$key;
  optionsRef: UpdateUpdateChannel_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: UpdateChannelData) => void;
  onDelete: () => void;
};

const UpdateUpdateChannel = ({
  updateChannelRef,
  optionsRef,
  isLoading = false,
  onSubmit,
  onDelete,
}: Props) => {
  const updateChannel = useFragment(
    UPDATE_UPDATE_CHANNEL_FRAGMENT,
    updateChannelRef,
  );

  const { deviceGroups: targetGroups } = useFragment(
    UPDATE_UPDATE_CHANNEL_OPTIONS_FRAGMENT,
    optionsRef,
  );

  const {
    register,
    handleSubmit,
    formState: { errors, isDirty },
    control,
    reset,
  } = useForm<UpdateChannel>({
    mode: "onTouched",
    defaultValues: updateChannel,
    resolver: yupResolver(updateChannelSchema),
  });

  useEffect(() => reset(updateChannel), [reset, updateChannel]);

  const intl = useIntl();

  const getTargetGroupLabel = useCallback(
    (targetGroup: TargetGroup) => {
      if (
        targetGroup.updateChannel === null ||
        targetGroup.updateChannel.id === updateChannel.id
      ) {
        return targetGroup.name;
      }
      return intl.formatMessage(
        {
          id: "forms.UpdateUpdateChannel.targetGroupWithChannelLabel",
          defaultMessage: "{targetGroupName} (used for {updateChannelName})",
          description:
            "Target group label of select option with optional update channel name it used for.",
        },
        {
          targetGroupName: targetGroup.name,
          updateChannelName: targetGroup.updateChannel.name,
        },
      );
    },
    [intl, updateChannel.id],
  );
  const isTargetGroupUsedByOtherChannel = useCallback(
    (targetGroup: TargetGroup) => {
      return !(
        targetGroup.updateChannel === null ||
        targetGroup.updateChannel.id === updateChannel.id
      );
    },
    [updateChannel.id],
  );

  const targetGroupOptions = useMemo(() => {
    // move disabled options to the end
    return [...targetGroups].sort((group1, group2) => {
      const group1Disabled = isTargetGroupUsedByOtherChannel(group1);
      const group2Disabled = isTargetGroupUsedByOtherChannel(group2);

      if (group1Disabled === group2Disabled) {
        return 0;
      }
      if (group1Disabled) {
        return 1;
      }
      return -1;
    });
  }, [targetGroups, isTargetGroupUsedByOtherChannel]);

  const onFormSubmit = (data: UpdateChannel) =>
    onSubmit(transformOutputData(data));

  const canSubmit = !isLoading && isDirty;

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="update-update-channel-form-name"
          label={
            <FormattedMessage
              id="forms.UpdateUpdateChannel.nameLabel"
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
          id="update-update-channel-form-handle"
          label={
            <FormattedMessage
              id="forms.UpdateUpdateChannel.handleLabel"
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
          id="update-update-channel-form-target-groups"
          label={
            <FormattedMessage
              id="forms.UpdateUpdateChannel.targetGroupsLabel"
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
        <div className="d-flex justify-content-end align-items-center gap-2">
          <Button variant="primary" type="submit" disabled={!canSubmit}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.UpdateUpdateChannel.submitButton"
              defaultMessage="Update"
            />
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="forms.UpdateUpdateChannel.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { UpdateChannelData };

export default UpdateUpdateChannel;
