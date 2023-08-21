/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

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

import { defineMessages, FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  UpdateTargetStatus as UpdateTargetStatusType,
  UpdateTargetStatus_UpdateTargetStatusFragment$key,
} from "api/__generated__/UpdateTargetStatus_UpdateTargetStatusFragment.graphql";

const UPDATE_TARGET_STATUS_FRAGMENT = graphql`
  fragment UpdateTargetStatus_UpdateTargetStatusFragment on UpdateTarget {
    status
  }
`;

const messages = defineMessages<UpdateTargetStatusType>({
  IDLE: {
    id: "components.updateTargetStatus.Idle",
    defaultMessage: "Idle",
  },
  IN_PROGRESS: {
    id: "components.updateTargetStatus.InProgress",
    defaultMessage: "In progress",
  },
  SUCCESSFUL: {
    id: "components.updateTargetStatus.Successful",
    defaultMessage: "Successful",
  },
  FAILED: {
    id: "components.updateTargetStatus.Failed",
    defaultMessage: "Failed",
  },
});

type UpdateTargetStatusProps = {
  status: UpdateTargetStatusType;
};
const UpdateTargetStatus = ({ status }: UpdateTargetStatusProps) => (
  <FormattedMessage id={messages[status].id} />
);

type UpdateTargetStatusFragmentProps = {
  updateTargetRef: UpdateTargetStatus_UpdateTargetStatusFragment$key;
};
const UpdateTargetStatusFragment = ({
  updateTargetRef,
}: UpdateTargetStatusFragmentProps) => {
  const { status } = useFragment(
    UPDATE_TARGET_STATUS_FRAGMENT,
    updateTargetRef
  );
  return <UpdateTargetStatus status={status} />;
};

type UpdateTargetStatusWrapperProps =
  | {
      status: UpdateTargetStatusType;
      updateTargetRef?: never;
    }
  | {
      status?: never;
      updateTargetRef: UpdateTargetStatus_UpdateTargetStatusFragment$key;
    };

const UpdateTargetStatusWrapper = (props: UpdateTargetStatusWrapperProps) =>
  props.updateTargetRef ? (
    <UpdateTargetStatusFragment updateTargetRef={props.updateTargetRef} />
  ) : (
    <UpdateTargetStatus status={props.status} />
  );

export type { UpdateTargetStatusType };
export { messages as statusMessages };

export default UpdateTargetStatusWrapper;
