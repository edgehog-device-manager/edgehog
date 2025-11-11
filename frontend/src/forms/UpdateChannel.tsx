/*
  This file is part of Edgehog.

  Copyright 2023 - 2025 SECO Mind Srl

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
import Form from "components/Form";
import MultiSelect from "components/MultiSelect";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { FormRow } from "components/FormRow";
import { channelHandleSchema, yup, messages } from "forms";

import type { UpdateChannel_ChannelFragment$key } from "api/__generated__/UpdateChannel_ChannelFragment.graphql";
import type {
  UpdateChannel_OptionsFragment$key,
  UpdateChannel_OptionsFragment$data,
} from "api/__generated__/UpdateChannel_OptionsFragment.graphql";

const UPDATE_UPDATE_CHANNEL_FRAGMENT = graphql`
  fragment UpdateChannel_ChannelFragment on Channel {
    id
    name
    handle
    targetGroups {
      edges {
        node {
          id
          name
          channel {
            id
            name
          }
        }
      }
    }
  }
`;

const UPDATE_UPDATE_CHANNEL_OPTIONS_FRAGMENT = graphql`
  fragment UpdateChannel_OptionsFragment on RootQueryType {
    deviceGroups {
      edges {
        node {
          id
          name
          channel {
            id
            name
          }
        }
      }
    }
  }
`;

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

type FormData = {
  id: string;
  name: string;
  handle: string;
  targetGroups: TargetGroup[];
};

type TargetGroup = NonNullable<
  NonNullable<UpdateChannel_OptionsFragment$data["deviceGroups"]>["edges"]
>[number]["node"];

const getTargetGroupValue = (targetGroup: TargetGroup) => targetGroup.id;

type ChannelData = {
  name: string;
  handle: string;
  targetGroupIds: string[];
};

const channelSchema = yup
  .object({
    name: yup.string().required(),
    handle: channelHandleSchema.required(),
    targetGroups: yup.array().ensure().min(1, messages.required.id),
  })
  .required();

const transformOutputData = ({
  id: _id,
  targetGroups,
  ...rest
}: FormData): ChannelData => ({
  ...rest,
  targetGroupIds: targetGroups.map((targetGroup) => targetGroup.id),
});

type Props = {
  channelRef: UpdateChannel_ChannelFragment$key;
  optionsRef: UpdateChannel_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: ChannelData) => void;
  onDelete: () => void;
};

const UpdateChannel = ({
  channelRef,
  optionsRef,
  isLoading = false,
  onSubmit,
  onDelete,
}: Props) => {
  const channel = useFragment(UPDATE_UPDATE_CHANNEL_FRAGMENT, channelRef);

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
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues: {
      ...channel,
      targetGroups: channel.targetGroups.edges?.map((edge) => edge.node),
    },
    resolver: yupResolver(channelSchema),
  });

  useEffect(() => {
    reset({
      ...channel,
      targetGroups: channel.targetGroups.edges?.map((edge) => edge.node),
    });
  }, [reset, channel]);

  const intl = useIntl();

  const getTargetGroupLabel = useCallback(
    (targetGroup: TargetGroup) => {
      if (
        targetGroup.channel === null ||
        targetGroup.channel.id === channel.id
      ) {
        return targetGroup.name;
      }
      return intl.formatMessage(
        {
          id: "forms.UpdateChannel.targetGroupWithChannelLabel",
          defaultMessage: "{targetGroupName} (used for {channelName})",
          description:
            "Target group label of select option with optional update channel name it used for.",
        },
        {
          targetGroupName: targetGroup.name,
          channelName: targetGroup.channel.name,
        },
      );
    },
    [intl, channel.id],
  );
  const isTargetGroupUsedByOtherChannel = useCallback(
    (targetGroup: TargetGroup) => {
      return !(
        targetGroup.channel === null || targetGroup.channel.id === channel.id
      );
    },
    [channel.id],
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
  }, [targetGroups, isTargetGroupUsedByOtherChannel]);

  const onFormSubmit = (data: FormData) => {
    onSubmit(transformOutputData(data));
  };

  const canSubmit = !isLoading && isDirty;
  const canReset = isDirty && !isLoading;

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="update-channel-form-name"
          label={
            <FormattedMessage
              id="forms.UpdateChannel.nameLabel"
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
          id="update-channel-form-handle"
          label={
            <FormattedMessage
              id="forms.UpdateChannel.handleLabel"
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
          id="update-channel-form-target-groups"
          label={
            <FormattedMessage
              id="forms.UpdateChannel.targetGroupsLabel"
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
        <Stack
          direction="horizontal"
          gap={3}
          className="justify-content-end align-items-center"
        >
          <Button variant="primary" type="submit" disabled={!canSubmit}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.UpdateChannel.submitButton"
              defaultMessage="Update"
            />
          </Button>
          <Button
            variant="secondary"
            disabled={!canReset}
            onClick={() => reset()}
          >
            <FormattedMessage
              id="forms.UpdateChannel.resetButton"
              defaultMessage="Reset"
            />
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="forms.UpdateChannel.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </Stack>
      </Stack>
    </form>
  );
};

export type { ChannelData };

export default UpdateChannel;
