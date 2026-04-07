// This file is part of Edgehog.
//
// Copyright 2023 - 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import { useMemo, useCallback, useState } from "react";
import { useForm, Controller } from "react-hook-form";
import { useIntl, FormattedMessage } from "react-intl";
import { zodResolver } from "@hookform/resolvers/zod";
import { graphql, usePaginationFragment } from "react-relay/hooks";

import type { CreateChannel_OptionsFragment$key } from "@/api/__generated__/CreateChannel_OptionsFragment.graphql";
import type { CreateChannel_PaginationQuery } from "@/api/__generated__/CreateChannel_PaginationQuery.graphql";

import Button from "@/components/Button";
import Form from "@/components/Form";
import MultiSelect from "@/components/MultiSelect";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { FormRow } from "@/components/FormRow";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";
import {
  ChannelFormData,
  channelSchema,
  TargetGroup,
} from "@/forms/validation";
import FormFeedback from "@/forms/FormFeedback";
import { ChannelOutputData } from "./UpdateChannel";

const CREATE_CHANNEL_OPTIONS_FRAGMENT = graphql`
  fragment CreateChannel_OptionsFragment on RootQueryType
  @refetchable(queryName: "CreateChannel_PaginationQuery")
  @argumentDefinitions(filter: { type: "DeviceGroupFilterInput" }) {
    deviceGroups(first: $first, after: $after, filter: $filter)
      @connection(key: "CreateChannel_deviceGroups") {
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

// react-hook-form returns targetGroups validation error as Array<Record<string, FieldError>> type
// ignoring eventual minimum length validation error type.
// TargetGroupsErrors handles errors as unknown and uses type guards to render type-safe error message.
// TODO: update RHF
const TargetGroupsErrors = ({ errors }: { errors: unknown }) => {
  const intl = useIntl();
  const fmt = intl.formatMessage;

  if (errors == null) {
    return null;
  }
  if (typeof errors === "object" && !Array.isArray(errors)) {
    if (
      "message" in errors &&
      typeof (errors as Record<"message", unknown>).message === "string"
    ) {
      const message = (errors as Record<"message", string>).message;
      return <>{fmt({ id: message })}</>;
    }
  }
  return null;
};

const getTargetGroupValue = (targetGroup: TargetGroup) => targetGroup.id;
const isTargetGroupUsedByOtherChannel = (targetGroup: TargetGroup) =>
  targetGroup.channel !== null;

const initialData: ChannelFormData = {
  name: "",
  handle: "",
  targetGroups: [],
};

type Props = {
  queryRef: CreateChannel_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: ChannelOutputData) => void;
};

const CreateChannelForm = ({
  queryRef,
  isLoading = false,
  onSubmit,
}: Props) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    CreateChannel_PaginationQuery,
    CreateChannel_OptionsFragment$key
  >(CREATE_CHANNEL_OPTIONS_FRAGMENT, queryRef);

  const [searchText, setSearchText] = useState<string | null>(null);

  const { onLoadMore } = useRelayConnectionPagination({
    hasNext,
    isLoadingNext,
    loadNext,
    refetch,
    searchText,
    buildFilter: (text) => {
      if (text === "") {
        return undefined;
      }

      return {
        name: {
          ilike: `%${text}%`,
        },
      };
    },
  });

  const targetGroups = useMemo(() => {
    return (
      paginationData.deviceGroups?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TargetGroup => node != null) ?? []
    );
  }, [paginationData]);

  const {
    register,
    handleSubmit,
    formState: { errors },
    control,
  } = useForm<ChannelFormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: zodResolver(channelSchema),
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
  }, [targetGroups]);

  const onFormSubmit = (data: ChannelFormData) => {
    const payload: ChannelOutputData = {
      name: data.name,
      handle: data.handle,
      targetGroupIds: data.targetGroups.map((tg) => tg.id),
    };

    onSubmit(payload);
  };

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
          <FormFeedback feedback={errors.name?.message} />
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
          <FormFeedback feedback={errors.handle?.message} />
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
                loading={isLoadingNext}
                onMenuScrollToBottom={onLoadMore}
                onInputChange={(text) => setSearchText(text)}
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

export default CreateChannelForm;
